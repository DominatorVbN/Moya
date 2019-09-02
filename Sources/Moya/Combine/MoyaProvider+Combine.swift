#if canImport(Combine)

import Foundation
import Combine

@available(OSX 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
public extension Publishable where Base: MoyaProviderType {

    /// Designated request-making method.
    ///
    /// - Parameters:
    ///   - target: Entity, which provides specifications necessary for a `MoyaProvider`.
    ///   - callbackQueue: Callback queue. If nil - queue from provider initializer will be used.
    /// - Returns: `AnyPublisher<Response, MoyaError`
    func request(_ target: Base.Target, callbackQueue: DispatchQueue? = nil) -> AnyPublisher<Response, MoyaError> {
        return MoyaPublisher { [weak base] subscriber in
                return base?.request(target, callbackQueue: callbackQueue, progress: nil) { result in
                    switch result {
                    case let .success(response):
                        _ = subscriber.receive(response)
                        subscriber.receive(completion: .finished)
                    case let .failure(error):
                        subscriber.receive(completion: .failure(error))
                    }
                }
            }
            .eraseToAnyPublisher()
    }

    /// Designated request-making method with progress.
    func requestWithProgress(_ target: Base.Target, callbackQueue: DispatchQueue? = nil) -> AnyPublisher<ProgressResponse, MoyaError> {
        let progressBlock: (AnySubscriber<ProgressResponse, MoyaError>) -> (ProgressResponse) -> Void = { subscriber in
            return { progress in
                _ = subscriber.receive(progress)
            }
        }

        let response = MoyaPublisher<ProgressResponse> { [weak base] subscriber in
            let cancellableToken = base?.request(target, callbackQueue: callbackQueue, progress: progressBlock(subscriber)) { result in
                switch result {
                case .success:
                    subscriber.receive(completion: .finished)
                case let .failure(error):
                    subscriber.receive(completion: .failure(error))
                }
            }

            return cancellableToken
        }

        // Accumulate all progress and combine them when the result comes
        return response
            .scan(ProgressResponse()) { last, progress in
                let progressObject = progress.progressObject ?? last.progressObject
                let response = progress.response ?? last.response
                return ProgressResponse(progress: progressObject, response: response)
            }
            .eraseToAnyPublisher()
    }
}

#endif
