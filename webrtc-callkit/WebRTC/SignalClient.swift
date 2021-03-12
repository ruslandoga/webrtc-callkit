import Foundation
import WebRTC
import SwiftPhoenixClient
import Promises

protocol SignalClientDelegate: class {
    func signalClient(_ signalClient: SignalClient, didReceiveRemoteSdp sdp: RTCSessionDescription)
    func signalClient(_ signalClient: SignalClient, didReceiveCandidate candidate: RTCIceCandidate)
}

final class SignalClient {
    private let decoder = JSONDecoder()
    private let encoder = JSONEncoder()
    private let channel: Channel
    
    enum Error: Swift.Error {
        case channelError(Message)
    }
    
    weak var delegate: SignalClientDelegate?
    
    init(channel: Channel) {
        // TODO track peer's presence
        self.channel = channel
        
        channel.delegateOn("peer-message", to: self) { (self, message) in
            guard let body = message.payload["body"] as? String,
                  let data = body.data(using: .utf8) else { return }
            
            let message: WebRTCMessage
            
            do {
                message = try self.decoder.decode(WebRTCMessage.self, from: data)
            } catch {
                debugPrint("Warning: Could not decode incoming message: \(error)")
                return
            }
            
            switch message {
            case let .candidate(iceCandidate):
                self.delegate?.signalClient(self, didReceiveCandidate: iceCandidate.rtcIceCandidate)
            case let .sdp(sessionDescription):
                self.delegate?.signalClient(self, didReceiveRemoteSdp: sessionDescription.rtcSessionDescription)
            }
        }
    }
    
    func send(sdp rtcSdp: RTCSessionDescription, to mate: UUID) -> Promise<()> {
        Promise { fulfill, reject in
            let message = WebRTCMessage.sdp(SessionDescription(from: rtcSdp))
            let dataMessage = try self.encoder.encode(message)
            self.channel.push("peer-message", payload: self.payload(mate: mate, data: dataMessage))
                .receive("ok") { _ in fulfill(())}
                .receive("error") { m in reject(Error.channelError(m))}
        }
    }
    
    func send(candidate rtcIceCandidate: RTCIceCandidate, to mate: UUID) -> Promise<()> {
        Promise { fulfill, reject in
            let message = WebRTCMessage.candidate(IceCandidate(from: rtcIceCandidate))
            let dataMessage = try self.encoder.encode(message)
            self.channel.push("peer-message", payload: self.payload(mate: mate, data: dataMessage))
                .receive("ok") { _ in fulfill(())}
                .receive("error") { m in reject(Error.channelError(m))}
        }
    }
    
    private func payload(mate: UUID, data: Data) -> [String: Any] {
        return [
            "mate": mate.lowerString,
            "body": String(data: data, encoding: .utf8)!
        ]
    }
}
