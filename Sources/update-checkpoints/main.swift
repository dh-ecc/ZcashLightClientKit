import GRPC
import NIO
import Foundation
import ZcashLightClientKit

print("woop")

let configuration = ClientConnection.Configuration(
  target: .hostAndPort("testnet.lightwalletd.com", 9067),
  eventLoopGroup: MultiThreadedEventLoopGroup(numberOfThreads: 1),
  tls: .init()
)

let channel = ClientConnection(configuration: configuration)

do {
  let latestBlockHeight = try LightWalletClient(channel: channel).getLatestBlock(ChainSpec()).response.wait().height
  let latestCheckpointSaved = WalletBirthday.birthday(with: BlockHeight(latestBlockHeight), network: ZcashNetworkBuilder.network(for: .testnet)).height
  let checkPointsToDownload = Array(stride(from: latestCheckpointSaved, through: Int(latestBlockHeight), by: 10000))
  for checkpoint in checkPointsToDownload {
    let response = try LightWalletClient(channel: channel).getTreeState(BlockID(jsonString: "{\"height\": \(checkpoint) }")).response.wait()
    print(response.serializedString())
  }
}

extension TreeState {
  func serializedString() -> String {
"""
{
  "network": "\(network)",
  "height": "\(height)",
  "hash": "\(hash)",
  "time": \(time),
  "tree": "\(tree)"
}

"""
  }
}
