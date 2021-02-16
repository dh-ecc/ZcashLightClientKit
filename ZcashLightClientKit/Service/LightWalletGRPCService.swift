//
//  ServiceHelper.swift
//  gRPC-PoC
//
//  Created by Francisco Gindre on 29/08/2019.
//  Copyright © 2019 Electric Coin Company. All rights reserved.
//

import Foundation
import GRPC
import NIO
import NIOHPACK
public typealias Channel = GRPC.GRPCChannel

extension TimeAmount {
    static let singleCallTimeout = TimeAmount.seconds(30)
    static let streamingCallTimeout = TimeAmount.seconds(90)
}
extension CallOptions {
    static var lwdCall: CallOptions {
        CallOptions(customMetadata: HPACKHeaders(),
                    timeLimit: .timeout(.singleCallTimeout),
                    messageEncoding: .disabled,
                    requestIDProvider: .autogenerated,
                    requestIDHeader: nil,
                    cacheable: false)
    }
}
/**
 Swift GRPC implementation of Lightwalletd service */
public class LightWalletGRPCService {
    
    var queue = DispatchQueue.init(label: "LightWalletGRPCService")
    let channel: Channel
    
    let compactTxStreamer: CompactTxStreamerClient
   
    public init(channel: Channel, timeout: TimeInterval = 10) {
        self.channel = channel
        compactTxStreamer = CompactTxStreamerClient(channel: self.channel, defaultCallOptions: Self.defaultCallOptions(with: timeout))
    }
    
    public convenience init(endpoint: LightWalletEndpoint) {
        self.init(host: endpoint.host, port: endpoint.port, secure: endpoint.secure)
    }
    
    public convenience init(host: String, port: Int = 9067, secure: Bool = true, timeout: TimeInterval = 10) {
        let configuration = ClientConnection.Configuration(target: .hostAndPort(host, port), eventLoopGroup: MultiThreadedEventLoopGroup(numberOfThreads: 1), tls: secure ? .init() : nil)
        let channel = ClientConnection(configuration: configuration)
        self.init(channel: channel, timeout: timeout)
    }
    
    func stop() {
        _ = channel.close()
    }
    
    func blockRange(startHeight: BlockHeight, endHeight: BlockHeight? = nil, result: @escaping (CompactBlock) -> Void) throws -> ServerStreamingCall<BlockRange, CompactBlock> {
        compactTxStreamer.getBlockRange(BlockRange(startHeight: startHeight, endHeight: endHeight), handler: result)
    }
    
    func latestBlock() throws -> BlockID {
        try compactTxStreamer.getLatestBlock(ChainSpec()).response.wait()
    }
    
    func getTx(hash: String) throws -> RawTransaction {
        var filter = TxFilter()
        filter.hash = Data(hash.utf8)
        return try compactTxStreamer.getTransaction(filter).response.wait()
    }
    
    static func defaultCallOptions(with timeout: TimeInterval) -> CallOptions {
        CallOptions(customMetadata: HPACKHeaders(),
                    timeLimit: .timeout(.singleCallTimeout),
                    messageEncoding: .disabled,
                    requestIDProvider: .autogenerated,
                    requestIDHeader: nil,
                    cacheable: false)
    }

}

extension LightWalletGRPCService: LightWalletService {
    public func fetchTransaction(txId: Data) throws -> TransactionEntity {
        var txFilter = TxFilter()
        txFilter.hash = txId
        
        do {
            let rawTx = try compactTxStreamer.getTransaction(txFilter).response.wait()
            
            return TransactionBuilder.createTransactionEntity(txId: txId, rawTransaction: rawTx)
        } catch {
            throw error.mapToServiceError()
        }
    }
    
    public func fetchTransaction(txId: Data, result: @escaping (Result<TransactionEntity, LightWalletServiceError>) -> Void) {
        
        var txFilter = TxFilter()
        txFilter.hash = txId
        
        compactTxStreamer.getTransaction(txFilter).response.whenComplete({ response in
            
            switch response {
            case .failure(let error):
                result(.failure(error.mapToServiceError()))
            case .success(let rawTx):
                result(.success(TransactionBuilder.createTransactionEntity(txId: txId, rawTransaction: rawTx)))
            }
        })
    }
    
    public func submit(spendTransaction: Data, result: @escaping (Result<LightWalletServiceResponse, LightWalletServiceError>) -> Void) {
        do {
            let tx = try RawTransaction(serializedData: spendTransaction)
            let response = self.compactTxStreamer.sendTransaction(tx).response
            
            response.whenComplete { (responseResult) in
                switch responseResult {
                case .failure(let e):
                    result(.failure(LightWalletServiceError.sentFailed(error: e)))
                case .success(let s):
                    result(.success(s))
                }
            }
        } catch {
            result(.failure(error.mapToServiceError()))
        }
    }
    
    public func submit(spendTransaction: Data) throws -> LightWalletServiceResponse {
        
        let rawTx = RawTransaction.with { (raw) in
            raw.data = spendTransaction
        }
        do {
            return try compactTxStreamer.sendTransaction(rawTx).response.wait()
        } catch {
            throw error.mapToServiceError()
        }
    }
    
    public func blockRange(_ range: CompactBlockRange) throws -> [ZcashCompactBlock] {
        var blocks = [CompactBlock]()
        
        let response = compactTxStreamer.getBlockRange(range.blockRange(), handler: {
            blocks.append($0)
        })
        
        let status = try response.status.wait()
        switch status.code {
        
        case .ok:
            do {
                return try blocks.asZcashCompactBlocks()
            } catch {
                LoggerProxy.error("invalid block in range: \(range) - Error: \(error)")
                throw LightWalletServiceError.genericError(error: error)
            }
        default:
            throw LightWalletServiceError.mapCode(status)
        }
    }
    
    public func latestBlockHeight(result: @escaping (Result<BlockHeight, LightWalletServiceError>) -> Void) {
        let response = compactTxStreamer.getLatestBlock(ChainSpec()).response
        
        response.whenSuccess { (blockID) in
            guard let blockHeight = Int(exactly: blockID.height) else {
                result(.failure(LightWalletServiceError.generalError(message: "error creating blockheight from BlockID \(blockID)")))
                return
            }
            result(.success(blockHeight))
        }
        
        response.whenFailure { (error) in
            result(.failure(error.mapToServiceError()))
        }
        
    }
    
    public func blockRange(_ range: CompactBlockRange, result: @escaping (Result<[ZcashCompactBlock], LightWalletServiceError>) -> Void) {

        queue.async { [weak self] in
            
            guard let self = self else { return }
            
            var blocks = [CompactBlock]()
            
            let response = self.compactTxStreamer.getBlockRange(range.blockRange(), handler: { blocks.append($0) })
            
            do {
                let status = try response.status.wait()
                switch status.code {
                case .ok:
                    do {
                        result(.success(try blocks.asZcashCompactBlocks()))
                    } catch {
                        LoggerProxy.error("Error parsing compact blocks \(error)")
                        result(.failure(LightWalletServiceError.invalidBlock))
                    }

                default:
                    result(.failure(.mapCode(status)))
                }
                
            } catch {
                result(.failure(error.mapToServiceError()))
            }
            
        }
        
    }
    
    public func latestBlockHeight() throws -> BlockHeight {
        
        guard let height = try? latestBlock().compactBlockHeight() else {
            throw LightWalletServiceError.invalidBlock
        }
        return height
    }
}

extension Error {
    func mapToServiceError() -> LightWalletServiceError {
        guard let grpcError = self as? GRPCStatusTransformable
               else {
            return LightWalletServiceError.genericError(error: self)
        }
        
        return LightWalletServiceError.mapCode(grpcError.makeGRPCStatus())
    }
}

extension LightWalletServiceError {
    static func mapCode(_ status: GRPCStatus) -> LightWalletServiceError {
        switch status.code {
        
        case .ok:
           return LightWalletServiceError.unknown
        case .cancelled:
            return LightWalletServiceError.userCancelled
        case .unknown:
            return LightWalletServiceError.unknown

        case .deadlineExceeded:
            return LightWalletServiceError.timeOut
        default:
            return LightWalletServiceError.genericError(error: status)
        }
    }
}
