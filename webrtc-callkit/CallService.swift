import SwiftPhoenixClient
import WebRTC
import CallKit

fileprivate func callProviderConfig() -> CXProviderConfiguration {
    let providerConfiguration = CXProviderConfiguration(localizedName: "webrtc-callkit")
    
    providerConfiguration.supportsVideo = false
    providerConfiguration.maximumCallsPerCallGroup = 1
    providerConfiguration.supportedHandleTypes = [.generic]
    
    return providerConfiguration
}

fileprivate func mate(from message: Message) -> UUID? {
    guard let mateStr = message.payload["mate"] as? String,
          let mate = UUID(uuidString: mateStr) else { return nil }
    return mate
}

fileprivate func configureAudioSession() {
    print("Configuring audio session")
    let session = AVAudioSession.sharedInstance()
    
    do {
        try session.setCategory(.playAndRecord, mode: .voiceChat, options: [])
    } catch {
        print("Error while configuring audio session: \(error)")
    }
}

final class CallService: NSObject {
    private let socket: Socket
    private let channel: Channel
    private let presence: Presence
    
    private var voiceCallMachine: VoiceCallMachine
    private let webrtcClient: WebRTCClient
    private let signalClient: SignalClient
    
    private let callController = CXCallController()
    private let callProvider: CXProvider
    
    init(socket: Socket, me: UUID) {
        print("call service init, \(socket)")
        self.socket = socket
        channel = socket.channel("matches:\(me.lowerString)")
        presence = Presence(channel: channel)
        
        // TODO turn servers
        webrtcClient = WebRTCClient(iceServers: ["stun:global.stun.twilio.com:3478?transport=udp"])
        signalClient = SignalClient(channel: channel)
        
        callProvider = CXProvider(configuration: callProviderConfig())
        voiceCallMachine = VoiceCallMachine(me: me)
    }
    
    deinit {
        channel.leave()
    }
    
    func start() {
        print("call service start")
        webrtcClient.delegate = self
        signalClient.delegate = self
        callProvider.setDelegate(self, queue: nil)
        
        channel.delegateOn("call", to: self) { (self, message) in
            guard let mate = mate(from: message) else { return }
            self.voiceCallMachine
                .process(input: .called(mate: mate))
                .forEach(self.interpret)
        }
        
        channel.delegateOn("pick-up", to: self) { (self, message) in
            guard let mate = mate(from: message) else { return }
            self.voiceCallMachine
                .process(input: .pickUp(mate: mate))
                .forEach(self.interpret)
        }
        
        channel.delegateOn("hang-up", to: self) { (self, message) in
            guard let mate = mate(from: message) else { return }
            self.voiceCallMachine
                .process(input: .hangUp(mate: mate))
                .forEach(self.interpret)
        }
        
        presence.onSync { [unowned self] in
            let presences = presence.list { id, _ in id }.compactMap(UUID.init)
            
            voiceCallMachine
                .process(input: .presenceChange(matesOnline: presences))
                .forEach(interpret)
        }
        
        socket.connect()
        
        channel.join()
            .receive("ok") { _ in print("joined") }
            .receive("error") { _ in print("error join") }
            .receive("timeout") { _ in print("join timeout") }
    }

    func call() {
        let mate = UUID(uuidString: "00000177-6518-778a-b8e8-56408d820000")!
        let tx = callTx(uuid: mate, handle: "Regina")
        request(transaction: tx, in: callController)
    }
    
    private func interpret(_ command: VoiceCallMachine.Output) {
        switch command {
        case let .reportOutgoingCall(mate: mate):
//            subscription?(.outgoingCall(mate: mate))
            callProvider.reportOutgoingCall(with: mate, startedConnectingAt: nil)
            configureAudioSession()
        
        case let .reportIncomingCall(mate: mate):
            let update = CXCallUpdate()
            update.hasVideo = false
            update.remoteHandle = CXHandle(type: .generic, value: mate.lowerString)
            callProvider.reportNewIncomingCall(with: mate, update: update) { error in
                if let error = error {
                    print("error reporting new call", error)
                }
            }
        
        case let .reportEndCall(mate: mate):
            request(transaction: endCallTx(uuid: mate), in: callController)
        
        case let .pushCall(mate: mate):
            channel.push("call", payload: ["mate": mate.lowerString])
                .receive("ok") { _ in print("[dev] push call \(mate)") }
                .receive("error") { _ in print("[dev] failed to push call \(mate)") }
        
        case let .pushPickUp(mate: mate):
            channel.push("pick-up", payload: ["mate": mate.lowerString])
                .receive("ok") { _ in print("[dev] pushed pick up \(mate)") }
                .receive("error") { _ in print("[dev] failed to push pick up \(mate)") }
            
        case let .pushHangUp(mate: mate):
            channel.push("hang-up", payload: ["mate": mate.lowerString])
                .receive("ok") { _ in
                    print("[dev] pushed hang up \(mate)")
                    self.webrtcClient.close()
//                    self.onRestart?()
                }
                .receive("error") { _ in print("[dev] failed to push hang up \(mate)") }
            
        case let .pushOffer(mate: mate):
            webrtcClient.offer().then { sdp in
                self.signalClient.send(sdp: sdp, to: mate)
            }
            
        case let .pushAnswer(mate: mate):
            webrtcClient.answer().then { sdp in
                self.signalClient.send(sdp: sdp, to: mate)
            }
        }
    }
    
    private func callTx(uuid: UUID, handle: String) -> CXTransaction {
        let handle = CXHandle(type: .generic, value: handle)
        let startCallAction = CXStartCallAction(call: uuid, handle: handle)
        startCallAction.isVideo = false
        return CXTransaction(action: startCallAction)
    }
    
    private func endCallTx(uuid: UUID) -> CXTransaction {
        return CXTransaction(action: CXEndCallAction(call: uuid))
    }
    
    private func request(transaction: CXTransaction, in controller: CXCallController) {
        controller.request(transaction) { error in
            // TODO return a promise
            if let error = error {
                print("Error requesting transaction: \(error)")
            } else {
                print("Requested transaction successfully")
            }
        }
    }
}

extension CallService: CXProviderDelegate {
    func providerDidReset(_ provider: CXProvider) {
        print("provider did reset")
    }
    
    func provider(_ provider: CXProvider, didActivate audioSession: AVAudioSession) {
        webrtcClient.audioSessionDidActivate(audioSession)
    }
    
    func provider(_ provider: CXProvider, didDeactivate audioSession: AVAudioSession) {
        webrtcClient.audioSessionDidDeactivate(audioSession)
    }
    
    func provider(_ provider: CXProvider, perform action: CXStartCallAction) {
        let mate = action.callUUID
        
        voiceCallMachine
            .process(input: .call(mate: mate))
            .forEach(interpret(_:))

        action.fulfill()
    }
    
    func provider(_ provider: CXProvider, perform action: CXAnswerCallAction) {
        let mate = action.callUUID
        
        voiceCallMachine
            .process(input: .pickUp(mate: mate))
            .forEach(interpret(_:))
        
        configureAudioSession()
        action.fulfill()
    }
    
    func provider(_ provider: CXProvider, perform action: CXEndCallAction) {
        let mate = action.callUUID
        
        // TODO how many times called?
        
        voiceCallMachine
            .process(input: .hangUp(mate: mate))
            .forEach(interpret(_:))
        
//        TODO deactivate audio session?

        action.fulfill()
    }
}

extension CallService: WebRTCClientDelegate {
    func webRTCClient(_ client: WebRTCClient, didDiscoverLocalCandidate candidate: RTCIceCandidate) {
        print("[dev] discovered local candidate")
        
        if let mate = voiceCallMachine.mate {
            print("[dev] sending candidate to \(mate)")
            
            signalClient.send(candidate: candidate, to: mate).then {
                print("[dev] sent candidate to \(mate)")
            }
        }
    }
    
    func webRTCClient(_ client: WebRTCClient, didChangeConnectionState state: RTCIceConnectionState) {
        // TODO possibly hang up on state change = lost
        print("[dev] didChangeConnectionState \(state)")
        switch state {
        // TODO push these states to voice call machine
        case .connected: callProvider.reportOutgoingCall(with: voiceCallMachine.mate!, startedConnectingAt: nil)
        default: ()
        }
    }
}

extension CallService: SignalClientDelegate {
    
    // TODO ensure it's from our mate
    func signalClient(_ signalClient: SignalClient, didReceiveRemoteSdp sdp: RTCSessionDescription) {
        print("[dev] received remote sdp")
        if let mate = voiceCallMachine.mate {
            webrtcClient.set(remoteSdp: sdp).then { print("[dev] set remove sdp") }
            
            if case .offer = sdp.type {
                voiceCallMachine
                    .process(input: .gotOffer(mate: mate))
                    .forEach(interpret)
            }
        }
    }
    
    // TODO ensure it's from our mate
    func signalClient(_ signalClient: SignalClient, didReceiveCandidate candidate: RTCIceCandidate) {
        print("[dev] Received remote candidate")
        webrtcClient.set(remoteCandidate: candidate)
    }
}
