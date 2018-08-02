//
//  ASBinder.swift
//
//  Created by Geektree0101.
//  Copyright(C) 2018 Geektree0101. All rights reserved.
//
import AsyncDisplayKit
import RxSwift
import RxCocoa

public struct ASBinder<Value>: ASObserverType {
    public typealias E = Value
    
    private let _binding: (Event<Value>) -> ()
    
    public init<Target: AnyObject>(_ target: Target,
                                   scheduler: ImmediateSchedulerType = MainScheduler(),
                                   binding: @escaping (Target, Value) -> ()) {
        weak var weakTarget = target
        
        _binding = { event in
            switch event {
            case .next(let element):
                _ = scheduler.schedule(element) { element in
                    if let target = weakTarget {
                        binding(target, element)
                    }
                    return Disposables.create()
                }
            case .error(let error):
                #if DEBUG
                    fatalError(error.localizedDescription)
                #else
                    print(error)
                #endif
            case .completed:
                break
            }
        }
    }
    
    public func on(_ event: Event<Value>, node: ASDisplayNode?) {
        _binding(event)
        
        if node?.isNodeLoaded ?? false {
            node?.setNeedsLayout()
        } else {
            /** Texture 2.7 layoutSpecThatFits constraintedSize issue
             constrainedSize has two kind of scale CGSize (min & max)
             But, If ASBinder bind with call `setNeedsLayout` before didLoad
             you will got equal minSize & maxSize  value
             maxium constraint size does not change when calling `setNeedsLayout` each time.
             **/
            _ = node?.rx.didLoad
                .observeOn(ConcurrentDispatchQueueScheduler(qos: .utility))
                .take(1)
                .subscribe(onNext: { [weak node] _ in
                    guard node?.isNodeLoaded ?? false else {
                        return
                    }
                    DispatchQueue.main.sync { }
                    node?.setNeedsLayout()
                })
        }
    }
    
    public func on(_ event: Event<Value>) {
        _binding(event)
    }
}

public protocol ASObserverType: ObserverType {
    func on(_ event: Event<E>, node: ASDisplayNode?)
}

extension ObservableType {
    public func bind<O>(to observer: O,
                        setNeedsLayout node: ASDisplayNode? = nil)
        -> Disposable where O : ASObserverType, Self.E == O.E {
            weak var weakNode = node
            return subscribe { event in
                switch event {
                case .next:
                    observer.on(event, node: weakNode)
                case .error(let error):
                    #if DEBUG
                        fatalError(error.localizedDescription)
                    #else
                        print(error)
                    #endif
                case .completed:
                    break
                }
            }
    }
    
    public func bind<O: ASObserverType>(to observer: O,
                                        setNeedsLayout node: ASDisplayNode? = nil)
        -> Disposable where O.E == E? {
            weak var weakNode = node
            return self.map { $0 }.subscribe { observerEvent in
                switch observerEvent {
                case .next:
                    observer.on(observerEvent.map({ Optional<Self.E>($0) }),
                                node: weakNode)
                case .error(let error):
                    #if DEBUG
                        fatalError(error.localizedDescription)
                    #else
                        print(error)
                    #endif
                case .completed:
                    break
                }
            }
    }
    
    public func bind(to relay: PublishRelay<E>,
                     setNeedsLayout node: ASDisplayNode?) -> Disposable {
        weak var weakNode = node
        return subscribe { e in
            switch e {
            case let .next(element):
                relay.accept(element)
                weakNode?.setNeedsLayout()
            case let .error(error):
                let log = "Binding error to publish relay: \(error)"
                #if DEBUG
                    fatalError(log)
                #else
                    print(log)
                #endif
            case .completed:
                break
            }
        }
    }
    
    public func bind(to relay: PublishRelay<E?>,
                     setNeedsLayout node: ASDisplayNode? = nil) -> Disposable {
        weak var weakNode = node
        return self.map { $0 as E? }
            .bind(to: relay, setNeedsLayout: weakNode)
    }
    
    public func bind(to relay: BehaviorRelay<E>,
                     setNeedsLayout node: ASDisplayNode? = nil) -> Disposable {
        weak var weakNode = node
        return subscribe { e in
            switch e {
            case let .next(element):
                relay.accept(element)
                weakNode?.setNeedsLayout()
            case let .error(error):
                let log = "Binding error to behavior relay: \(error)"
                #if DEBUG
                    fatalError(log)
                #else
                    print(log)
                #endif
            case .completed:
                break
            }
        }
    }
    
    public func bind(to relay: BehaviorRelay<E?>,
                     setNeedsLayout node: ASDisplayNode? = nil) -> Disposable {
        weak var weakNode = node
        return self.map { $0 as E? }
            .bind(to: relay, setNeedsLayout: weakNode)
    }
}