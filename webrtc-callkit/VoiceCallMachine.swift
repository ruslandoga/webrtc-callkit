import Foundation

struct VoiceCallMachine {
    enum State {
        /// Before any interaction
        case none
        /// I'm calling a mate
        case calling(mate: UUID)
        /// Mate's calling me
        case called(mate: UUID)
        /// Someone called, the other picked up
        case pickedUp(mate: UUID)
    }
    
    enum Input {
        /// I call a mate
        case call(mate: UUID)
        /// Mate called me
        case called(mate: UUID)
        /// I pick up, or mate picks up
        case pickUp(mate: UUID)
        /// Mate sends offer
        case gotOffer(mate: UUID)
        /// I hang up or mate hangs up
        case hangUp(mate: UUID)
        /// Someone goes online or offline, maybe it's mate?
        case presenceChange(matesOnline: [UUID])
    }
    
    enum Output {
        /// Commnd to push "call" to mate via backend
        case pushCall(mate: UUID)
        /// Command to push "pick-up" to mate via backend
        case pushPickUp(mate: UUID)
        /// Command to push "hang-up" to mate via backend
        case pushHangUp(mate: UUID)
        /// Command to push webrts offer to mate via backend
        case pushOffer(mate: UUID)
        /// Command to push webrtc answer to mate via backend
        case pushAnswer(mate: UUID)
        
//        case reportIncomingCall
//        case report 
    }
    
    var state: State = .none
    let me: UUID
    
    init(me: UUID) {
        self.me = me
    }
}

extension VoiceCallMachine {
    var mate: UUID? {
        switch state {
        case let .called(mate: mate),
             let .calling(mate: mate),
             let .pickedUp(mate: mate): return mate
        case .none:
            return nil
        }
    }
}

extension VoiceCallMachine {
    mutating func process(input: Input) -> [Output] {
        switch input {
        case let .call(mate: mate): return processCall(mate: mate)
        case let .called(mate: mate): return processReceiveCall(mate: mate)
        case let .pickUp(mate: mate): return processPickUp(mate: mate)
        case let .gotOffer(mate: mate): return processGotOffer(mate: mate)
        case let .hangUp(mate: mate): return processHangUp(mate: mate)
        case let .presenceChange(matesOnline: matesOnline): return processPresenceChange(matesOnline: matesOnline)
        }
    }

    private mutating func processCall(mate: UUID) -> [Output] {
        // me not doing much, and then me called mate
        if case .none = state {
            state = .calling(mate: mate)
            return [.pushCall(mate: mate)]
        }

        return []
    }
    
    private mutating func processReceiveCall(mate: UUID) -> [Output] {
        switch state {
        // me calling mate, mate calling me
        case let .calling(mate: calling) where calling == mate && me < mate:
            state = .pickedUp(mate: mate)
            return [.pushPickUp(mate: mate), .pushOffer(mate: mate)]
        case let .calling(mate: calling) where calling == mate:
            state = .pickedUp(mate: mate)
            return [.pushPickUp(mate: mate)]
        
        // me not doing much, mate called me
        case .none:
            state = .called(mate: mate)
            return []
        
        default:
            return []
        }
    }
    
    // TODO split into processRemotePickUp and processLocalPickUp?
    private mutating func processPickUp(mate: UUID) -> [Output] {
        switch state {
        // mate picked up me
        case let .calling(mate: calling) where calling == mate && me < mate:
            state = .pickedUp(mate: mate)
            return [.pushOffer(mate: mate)]
        case let .calling(mate: calling) where calling == mate:
            state = .pickedUp(mate: mate)
            return []
        
        // me picked up mate
        case let .called(mate: called) where called == mate && me < mate:
            state = .pickedUp(mate: mate)
            return [.pushPickUp(mate: mate), .pushOffer(mate: mate)]
        case let .called(mate: called) where called == mate:
            state = .pickedUp(mate: mate)
            return [.pushPickUp(mate: mate)]
        
        default:
            return []
        }
    }
    
    private mutating func processGotOffer(mate: UUID) -> [Output] {
        switch state {
        // mate sent offer which me was expecting
        case let .pickedUp(mate: pickedUp) where pickedUp == mate && me > mate:
            return [.pushAnswer(mate: mate)]
        default:
            return []
        }
    }
    
    // TODO split into processRemoteHangUp and processLocalHangUp to better express UI?
    private mutating func processHangUp(mate: UUID) -> [Output] {
        switch state {
        // mate called and then either me hanged up on mate or mate changed mind and hang up
        case let .called(mate: called) where called == mate:
            state = .none
            return [.pushHangUp(mate: mate)]
        // me was calling mate and then either me changed mind and hang up or mate hang up
        case let .calling(mate: calling) where calling == mate:
            state = .none
            return [.pushHangUp(mate: mate)]
        // me and mate were having a convo and then someone hang up
        case let .pickedUp(mate: pickedUp) where pickedUp == mate:
            // TODO who hang up? if it was mate, no need to push
            state = .none
            return [.pushHangUp(mate: mate)]
        
        default:
            return []
        }
    }
    
    private mutating func processPresenceChange(matesOnline: [UUID]) -> [Output] {
        switch state {
        // mate called me and then went offline
        case let .called(mate: mate) where !matesOnline.contains(mate): state = .none
        // me called mate and mate went offline
        case let .calling(mate: mate) where !matesOnline.contains(mate): state = .none
        // me and mate are ready for call and then mate went offline
        // TODO not sure about this, what if webrtc connection is still alive?
        case let .pickedUp(mate: mate) where !matesOnline.contains(mate): state = .none
        
        default: ()
        }
        
        return []
    }
}

extension VoiceCallMachine.State: Equatable {}
