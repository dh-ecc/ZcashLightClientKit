//
// DO NOT EDIT.
//
// Generated by the protocol buffer compiler.
// Source: service.proto
//

//
// Copyright 2018, gRPC Authors All rights reserved.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//
import GRPC
import NIO
import SwiftProtobuf


/// Usage: instantiate CompactTxStreamerClient, then call methods of this protocol to make API calls.
struct LightWalletClient: GRPCClient {
    let channel: GRPCChannel
    var defaultCallOptions: CallOptions = .init()
    /// - Parameters:
    ///   - request: Request to send to GetTreeState.
    ///   - callOptions: Call options.
    /// - Returns: A `UnaryCall` with futures for the metadata, status and response.
    func getTreeState(
        _ request: BlockID,
        callOptions: CallOptions? = nil
    ) -> UnaryCall<BlockID, TreeState> {
        return self.makeUnaryCall(
            path: "/cash.z.wallet.sdk.rpc.CompactTxStreamer/GetTreeState",
            request: request,
            callOptions: callOptions ?? self.defaultCallOptions
        )
    }

  func getLatestBlock(
    _ request: ChainSpec,
    callOptions: CallOptions? = nil
  ) -> UnaryCall<ChainSpec, BlockID> {
    return self.makeUnaryCall(
      path: "/cash.z.wallet.sdk.rpc.CompactTxStreamer/GetLatestBlock",
      request: request,
      callOptions: callOptions ?? self.defaultCallOptions
    )
  }
}