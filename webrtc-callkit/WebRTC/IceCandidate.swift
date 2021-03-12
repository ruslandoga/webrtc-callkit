import Foundation
import WebRTC

/// This struct is a swift wrapper over `RTCIceCandidate` for easy encode and decode
struct IceCandidate: Codable {
    let candidate: String
    let sdpMLineIndex: Int32
    let sdpMid: String?
    
    init(from iceCandidate: RTCIceCandidate) {
        self.sdpMLineIndex = iceCandidate.sdpMLineIndex
        self.sdpMid = iceCandidate.sdpMid
        self.candidate = iceCandidate.sdp
    }
    
    var rtcIceCandidate: RTCIceCandidate {
        return RTCIceCandidate(sdp: candidate, sdpMLineIndex: sdpMLineIndex, sdpMid: sdpMid)
    }
}
