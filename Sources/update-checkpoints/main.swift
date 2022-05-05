import GRPC
import NIO
import Foundation
import ZcashLightClientKit

print("woop")

let configuration = ClientConnection.Configuration(
  target: .hostAndPort("mainnet.lightwalletd.com", 9067),
  eventLoopGroup: MultiThreadedEventLoopGroup(numberOfThreads: 1),
  tls: .init()
)

let channel = ClientConnection(configuration: configuration)

do {
  let latestBlockHeight = try LightWalletClient(channel: channel).getLatestBlock(ChainSpec()).response.wait().height
  let latestCheckpointSaved = WalletBirthday.birthday(with: 1640003, network: ZcashNetworkBuilder.network(for: .mainnet)).height

  let thing = Array(stride(from: 1640000, through: Int(latestBlockHeight), by: 10000))
  print(thing)

  let response = try LightWalletClient(channel: channel).getTreeState(BlockID(jsonString: "{\"height\": \(latestBlockHeight) }")).response.wait()
  let string = response.serializedString()
  print(string)
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

//do {
//  let x = try LightWalletClient(channel: channel).getTreeState(BlockID(jsonString: "{\"height\": 1610000 }")).response.wait()
//  print(x.serializedString())
//
//
//    let encoder = JSONEncoder()
//    if #available(macOS 10.13, *) {
//        encoder.outputFormatting = [.prettyPrinted]
//    } else {
//        fatalError()
//    }
//    let json = try encoder.encode(TreeStateJSON(treeState: x))
//  print(String(data: json, encoding: .utf8)!)
//  print("******")
//  print(try! x.jsonString())
//  print("******")
//  print(try! x.jsonString()
//          .replacingOccurrences(of: ",", with: ",\n  ")
//          .replacingOccurrences(of: "{", with: "{\n  ")
//          .replacingOccurrences(of: "}", with: "\n}")
//          .replacingOccurrences(of: ":", with: ": ")
//  )
//  print("******")
//  let mirror = Mirror(reflecting: TreeStateJSON(treeState: x))
//  let text = mirror.children.map{
//    "\($0.label!): "
//  }.joined(separator: "\n")
//  print(mirror.children.map(\.value))
//  print("*****")
//


//extension Data {
//  var prettyPrintedJSONString: NSString? { /// NSString gives us a nice sanitized debugDescription
//    guard let object = try? JSONSerialization.jsonObject(with: self, options: []),
//          let data = try? JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted]),
//          let prettyPrintedString = NSString(data: data, encoding: String.Encoding.utf8.rawValue) else { return nil }
//
//    return prettyPrintedString
//  }
//}
//
//struct TreeStateJSON: Codable {
//  var network: String
//  var height: UInt64
//  var hash: String
//  var time: UInt32
//  var tree: String
//
//  enum CodingKeys: String, CodingKey {
//    case network
//    case height
//    case hash
//    case time
//    case tree
//  }
//
//  func encode(to encoder: Encoder) throws {
//    var container = encoder.container(keyedBy: CodingKeys.self)
//    try container.encode(network, forKey: .network)
//    try container.encode(height, forKey: .height)
//    try container.encode(hash, forKey: .hash)
//    try container.encode(time, forKey: .time)
//    try container.encode(tree, forKey: .tree)
//  }
//}
//
//extension TreeStateJSON {
//    init(treeState: TreeState) {
//        self.network = treeState.network
//        self.height = treeState.height
//        self.hash = treeState.hash
//        self.time = treeState.time
//        self.tree = treeState.tree
//    }
//}
