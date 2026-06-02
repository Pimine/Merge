//
// Copyright (c) Vatsal Manot
//

#if os(macOS)

@globalActor
public actor _ShellActor {
    public actor ActorType {
        fileprivate init() {

        }
    }

    public static let shared: ActorType = ActorType()
}

#endif
