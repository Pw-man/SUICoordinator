//
//  CoordinatorType.swift
//
//  Copyright (c) Andres F. Lozano
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//  THE SOFTWARE.
//

import Foundation

extension CoordinatorType {
    
    /// The root router associated with the coordinator.
    var root: (any RouterType) {
        return router
    }
    
    /// A boolean value indicating whether the coordinator is tabbar-coordinable.
    var isTabbarCoordinable: Bool {
        self is (any TabbarCoordinatable)
    }
    
    
    /// Cleans the view associated with the coordinator.
    ///
    /// - Parameters:
    ///   - animated: A boolean value indicating whether to animate the cleaning process.
    ///   - withMainView: A boolean value indicating whether to clean the main view.
    func cleanView(animated: Bool = false, withMainView: Bool = true) async {
        await router.clean(animated: animated, withMainView: withMainView)
        parent = nil
    }
    
    /// Retrieves a deep coordinator from the provided value.
    ///
    /// - Parameters:
    ///   - value: An inout parameter containing the coordinator value.
    /// - Returns: An optional deep coordinator of type TCoordinatorType.
    /// - Throws: An error if the deep coordinator retrieval fails.
    func getDeepCoordinator(from value: inout TCoordinatorType?) throws -> TCoordinatorType? {
        if value?.children.last == nil {
            return value
        } else if let value = value, let tabCoordinator = getTabbarCoordinable(value) {
            return try topCoordinator(pCoodinator: try tabCoordinator.getCoordinatorSelected())
        } else {
            var last = value?.children.last
            return try getDeepCoordinator(from: &last)
        }
    }
    
    /// Removes a child coordinator from the children array.
    ///
    /// - Parameters:
    ///   - coordinator: The child coordinator to be removed.
    func removeChild(coordinator : TCoordinatorType) async {
        guard let index = children.firstIndex(where: {$0.uuid == coordinator.uuid}) else {
            return
        }
        children.remove(at: index)
        await coordinator.removeChildren()
        await removeChild(coordinator: coordinator)
    }
    
    /// Removes all child coordinators associated with this coordinator.
    ///
    /// - Parameters:
    ///   - animated: A boolean value indicating whether to animate the removal process.
    func removeChildren(animated: Bool = false) async {
        guard let first = children.first else { return }
        await first.handleFinish(animated: animated, withDissmis: false)
        await removeChildren()
    }
    
    /// Retrieves the tabbar-coordinable object associated with the provided coordinator.
    ///
    /// - Parameters:
    ///   - coordinator: The coordinator for which to retrieve the tabbar-coordinable object.
    /// - Returns: An optional tabbar-coordinable object conforming to any TabbarCoordinatable.
    func getTabbarCoordinable(_ coordinator: TCoordinatorType) ->  (any TabbarCoordinatable)? {
        coordinator as? (any TabbarCoordinatable)
    }
    
    /// Starts a child coordinator.
    ///
    /// - Parameters:
    ///   - coordinator: The child coordinator to be started.
    func startChildCoordinator(_ coordinator: TCoordinatorType) {
        children.append(coordinator)
        coordinator.parent = self
    }
    
    /// Dismisses the last presented sheet.
    ///
    /// - Parameters:
    ///   - animated: A boolean value indicating whether to animate the dismissal.
    func dismissLastSheet(animated: Bool = true) async {
        await router.dismiss(animated: animated)
    }
    
    /// Cleans up the coordinator, preparing it for dismissal.
    ///
    /// - Parameters:
    ///   - animated: A boolean value indicating whether to animate the cleanup process.
    func emptyCoordinator(animated: Bool) async {
        guard let parent = parent else {
            await router.restart(animated: animated)
            await cleanView(animated: false)
            return await removeChildren()
        }
        
        await parent.removeChild(coordinator: self)
        await cleanView(animated: false)
    }
    
    /// Handles the finish event, optionally dismissing the coordinator.
    ///
    /// - Parameters:
    ///   - animated: A boolean value indicating whether to animate the finish process.
    ///   - withDissmis: A boolean value indicating whether to dismiss the coordinator.
    func handleFinish(animated: Bool = true, withDissmis: Bool = true) async {
        guard withDissmis else {
            return await emptyCoordinator(animated: animated)
        }
        await router.close(animated: animated, finishFlow: true)
        await emptyCoordinator(animated: animated)
    }
    
    /// Finishes the coordinator, optionally dismissing it.
    ///
    /// - Parameters:
    ///   - animated: A boolean value indicating whether to animate the finish process.
    ///   - withDissmis: A boolean value indicating whether to dismiss the coordinator.
    /// - Returns: An asynchronous void task representing the finish process.
    func finish(animated: Bool = true, withDissmis: Bool = true) async -> Void {
        let handleFinish = { (coordinator: TCoordinatorType) async -> Void in
            await coordinator.handleFinish(
                animated: animated,
                withDissmis: withDissmis
            )
        }
        
        if let parent, (parent is (any TabbarCoordinatable)) {
            await router.close(animated: animated, finishFlow: true)
            await handleFinish(parent)
        } else {
            await handleFinish(self)
        }
    }
}
