// DO NOT EDIT.
// swift-format-ignore-file
//
// Generated by the Swift generator plugin for the protocol buffer compiler.
// Source: flow/entities/block_seal.proto
//
// For information on using the generated types, please see the documentation:
//   https://github.com/apple/swift-protobuf/

import Foundation
import SwiftProtobuf

// If the compiler emits an error on this type, it is because this file
// was generated by a version of the `protoc` Swift plug-in that is
// incompatible with the version of SwiftProtobuf to which you are linking.
// Please ensure that you are building against the same version of the API
// that was used to generate this file.
fileprivate struct _GeneratedWithProtocGenSwiftVersion: SwiftProtobuf.ProtobufAPIVersionCheck {
  struct _2: SwiftProtobuf.ProtobufAPIVersion_2 {}
  typealias Version = _2
}

public struct Flow_Entities_BlockSeal {
  // SwiftProtobuf.Message conformance is added in an extension below. See the
  // `Message` and `Message+*Additions` files in the SwiftProtobuf library for
  // methods supported on all messages.

  public var blockID: Data = Data()

  public var executionReceiptID: Data = Data()

  public var executionReceiptSignatures: [Data] = []

  public var resultApprovalSignatures: [Data] = []

  public var finalState: Data = Data()

  public var resultID: Data = Data()

  public var aggregatedApprovalSigs: [Flow_Entities_AggregatedSignature] = []

  public var unknownFields = SwiftProtobuf.UnknownStorage()

  public init() {}
}

public struct Flow_Entities_AggregatedSignature {
  // SwiftProtobuf.Message conformance is added in an extension below. See the
  // `Message` and `Message+*Additions` files in the SwiftProtobuf library for
  // methods supported on all messages.

  public var verifierSignatures: [Data] = []

  public var signerIds: [Data] = []

  public var unknownFields = SwiftProtobuf.UnknownStorage()

  public init() {}
}

#if swift(>=5.5) && canImport(_Concurrency)
extension Flow_Entities_BlockSeal: @unchecked Sendable {}
extension Flow_Entities_AggregatedSignature: @unchecked Sendable {}
#endif  // swift(>=5.5) && canImport(_Concurrency)

// MARK: - Code below here is support for the SwiftProtobuf runtime.

fileprivate let _protobuf_package = "flow.entities"

extension Flow_Entities_BlockSeal: SwiftProtobuf.Message, SwiftProtobuf._MessageImplementationBase, SwiftProtobuf._ProtoNameProviding {
  public static let protoMessageName: String = _protobuf_package + ".BlockSeal"
  public static let _protobuf_nameMap: SwiftProtobuf._NameMap = [
    1: .standard(proto: "block_id"),
    2: .standard(proto: "execution_receipt_id"),
    3: .standard(proto: "execution_receipt_signatures"),
    4: .standard(proto: "result_approval_signatures"),
    5: .standard(proto: "final_state"),
    6: .standard(proto: "result_id"),
    7: .standard(proto: "aggregated_approval_sigs"),
  ]

  public mutating func decodeMessage<D: SwiftProtobuf.Decoder>(decoder: inout D) throws {
    while let fieldNumber = try decoder.nextFieldNumber() {
      // The use of inline closures is to circumvent an issue where the compiler
      // allocates stack space for every case branch when no optimizations are
      // enabled. https://github.com/apple/swift-protobuf/issues/1034
      switch fieldNumber {
      case 1: try { try decoder.decodeSingularBytesField(value: &self.blockID) }()
      case 2: try { try decoder.decodeSingularBytesField(value: &self.executionReceiptID) }()
      case 3: try { try decoder.decodeRepeatedBytesField(value: &self.executionReceiptSignatures) }()
      case 4: try { try decoder.decodeRepeatedBytesField(value: &self.resultApprovalSignatures) }()
      case 5: try { try decoder.decodeSingularBytesField(value: &self.finalState) }()
      case 6: try { try decoder.decodeSingularBytesField(value: &self.resultID) }()
      case 7: try { try decoder.decodeRepeatedMessageField(value: &self.aggregatedApprovalSigs) }()
      default: break
      }
    }
  }

  public func traverse<V: SwiftProtobuf.Visitor>(visitor: inout V) throws {
    if !self.blockID.isEmpty {
      try visitor.visitSingularBytesField(value: self.blockID, fieldNumber: 1)
    }
    if !self.executionReceiptID.isEmpty {
      try visitor.visitSingularBytesField(value: self.executionReceiptID, fieldNumber: 2)
    }
    if !self.executionReceiptSignatures.isEmpty {
      try visitor.visitRepeatedBytesField(value: self.executionReceiptSignatures, fieldNumber: 3)
    }
    if !self.resultApprovalSignatures.isEmpty {
      try visitor.visitRepeatedBytesField(value: self.resultApprovalSignatures, fieldNumber: 4)
    }
    if !self.finalState.isEmpty {
      try visitor.visitSingularBytesField(value: self.finalState, fieldNumber: 5)
    }
    if !self.resultID.isEmpty {
      try visitor.visitSingularBytesField(value: self.resultID, fieldNumber: 6)
    }
    if !self.aggregatedApprovalSigs.isEmpty {
      try visitor.visitRepeatedMessageField(value: self.aggregatedApprovalSigs, fieldNumber: 7)
    }
    try unknownFields.traverse(visitor: &visitor)
  }

  public static func ==(lhs: Flow_Entities_BlockSeal, rhs: Flow_Entities_BlockSeal) -> Bool {
    if lhs.blockID != rhs.blockID {return false}
    if lhs.executionReceiptID != rhs.executionReceiptID {return false}
    if lhs.executionReceiptSignatures != rhs.executionReceiptSignatures {return false}
    if lhs.resultApprovalSignatures != rhs.resultApprovalSignatures {return false}
    if lhs.finalState != rhs.finalState {return false}
    if lhs.resultID != rhs.resultID {return false}
    if lhs.aggregatedApprovalSigs != rhs.aggregatedApprovalSigs {return false}
    if lhs.unknownFields != rhs.unknownFields {return false}
    return true
  }
}

extension Flow_Entities_AggregatedSignature: SwiftProtobuf.Message, SwiftProtobuf._MessageImplementationBase, SwiftProtobuf._ProtoNameProviding {
  public static let protoMessageName: String = _protobuf_package + ".AggregatedSignature"
  public static let _protobuf_nameMap: SwiftProtobuf._NameMap = [
    1: .standard(proto: "verifier_signatures"),
    2: .standard(proto: "signer_ids"),
  ]

  public mutating func decodeMessage<D: SwiftProtobuf.Decoder>(decoder: inout D) throws {
    while let fieldNumber = try decoder.nextFieldNumber() {
      // The use of inline closures is to circumvent an issue where the compiler
      // allocates stack space for every case branch when no optimizations are
      // enabled. https://github.com/apple/swift-protobuf/issues/1034
      switch fieldNumber {
      case 1: try { try decoder.decodeRepeatedBytesField(value: &self.verifierSignatures) }()
      case 2: try { try decoder.decodeRepeatedBytesField(value: &self.signerIds) }()
      default: break
      }
    }
  }

  public func traverse<V: SwiftProtobuf.Visitor>(visitor: inout V) throws {
    if !self.verifierSignatures.isEmpty {
      try visitor.visitRepeatedBytesField(value: self.verifierSignatures, fieldNumber: 1)
    }
    if !self.signerIds.isEmpty {
      try visitor.visitRepeatedBytesField(value: self.signerIds, fieldNumber: 2)
    }
    try unknownFields.traverse(visitor: &visitor)
  }

  public static func ==(lhs: Flow_Entities_AggregatedSignature, rhs: Flow_Entities_AggregatedSignature) -> Bool {
    if lhs.verifierSignatures != rhs.verifierSignatures {return false}
    if lhs.signerIds != rhs.signerIds {return false}
    if lhs.unknownFields != rhs.unknownFields {return false}
    return true
  }
}
