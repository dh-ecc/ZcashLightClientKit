import GRPC
import NIO
import Foundation

print("helloo")

let configuration = ClientConnection.Configuration(
    target: .hostAndPort("mainnet.lightwalletd.com", 9067),
    eventLoopGroup: MultiThreadedEventLoopGroup(numberOfThreads: 1),
    tls: .init()
)
let channel = ClientConnection(configuration: configuration)

do {
    let x = try LightWalletClient(channel: channel).getTreeState(BlockID(jsonString: "{\"height\": 1610000 }")).response.wait()
    let encoder = JSONEncoder()
    if #available(macOS 10.13, *) {
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    } else {
        fatalError()
    }
    let json = try encoder.encode(TreeStateJSON(treeState: x))
    print(String(data: json, encoding: .utf8)!)
  print(try! x.jsonString())
  print("******")
  print(try! x.jsonString()
          .replacingOccurrences(of: ",", with: ",\n  ")
          .replacingOccurrences(of: "{", with: "{\n  ")
          .replacingOccurrences(of: "}", with: ",\n}")
  )

}

extension Data {
  var prettyPrintedJSONString: NSString? { /// NSString gives us a nice sanitized debugDescription
    guard let object = try? JSONSerialization.jsonObject(with: self, options: []),
          let data = try? JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted]),
          let prettyPrintedString = NSString(data: data, encoding: String.Encoding.utf8.rawValue) else { return nil }

    return prettyPrintedString
  }
}

struct TreeStateJSON: Codable {
        var network: String
        var height: UInt64
        var hash: String
        var time: UInt32
        var tree: String
}

extension TreeStateJSON {
    init(treeState: TreeState) {
        self.network = treeState.network
        self.height = treeState.height
        self.hash = treeState.hash
        self.time = treeState.time
        self.tree = treeState.tree
    }
}
