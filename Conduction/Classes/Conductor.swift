//
//  Conductor.swift
//  GigSalad
//
//  Created by Gregory Klein on 2/13/17.
//  Copyright © 2017 Incipia. All rights reserved.
//

import UIKit

/*
 Conductor: A class that owns one or more view controllers, acts as their delegate if applicable, and encompasses the logic
         that's used for navigating the user through a specific 'flow'
 */

open class Conductor: NSObject {
   public weak var context: UINavigationController?
   weak var topBeforeShowing: UIViewController?
   weak var previousContextDelegate: UINavigationControllerDelegate?
   
   public var dismissBlock: (() -> Void) = {}
   
   fileprivate var _isShowing: Bool = false

   // Meant to be overridden
   open var rootViewController: UIViewController? {
      fatalError("\(#function) needs to be overridden")
   }
   
   open func conductorWillShow(in context: UINavigationController) {
   }
   
   open func conductorDidShow(in context: UINavigationController) {
   }
   
   open func conductorWillDismiss(from context: UINavigationController) {
   }
   
   open func conductorDidDismiss(from context: UINavigationController) {
      print("\(type(of: self)) did dismiss")
   }
   
   public func show(with context: UINavigationController, animated: Bool = false) {
      guard self.context == nil else { fatalError("Conductor (\(self)) already has a context: \(String(describing: self.context))") }
      guard let rootViewController = rootViewController else { fatalError("Conductor (\(self)) has no root view controller") }
      self.context = context
      self.topBeforeShowing = context.topViewController
      
      previousContextDelegate = context.delegate
      context.delegate = self
      context.pushViewController(rootViewController, animated: animated)
   }
   
   @objc public func dismiss() {
      guard let topBeforeShowing = topBeforeShowing else { return }
      _ = context?.popToViewController(topBeforeShowing, animated: true)
   }
   
   @discardableResult @objc public func reset() -> Bool {
      guard let rootViewController = rootViewController else { return false }
      _ = context?.popToViewController(rootViewController, animated: true)
      return true
   }
   
   fileprivate func _dismiss() {
      guard _isShowing else { fatalError("\(#function) called when \(self) is not showing") }
      
      _isShowing = false
      context?.delegate = previousContextDelegate
      previousContextDelegate = nil
      context = nil
      dismissBlock()
   }
}

open class TabConductor: Conductor {
   weak var tabBarController: UITabBarController?
   
   public func show(in tabBarController: UITabBarController, with context: UINavigationController, animated: Bool = false) {
      show(with: context)
      var vcs: [UIViewController] = tabBarController.viewControllers ?? []
      vcs.append(context)
      tabBarController.viewControllers = vcs
      self.tabBarController = tabBarController
   }
   
   public func show() {
      guard let context = context, let index = tabBarController?.viewControllers?.index(of: context) else { return }
      tabBarController?.selectedIndex = index
   }
   
   override public func dismiss() {
      fatalError("dismiss not yet implemented for TabConductor")
   }
}

extension Conductor: UINavigationControllerDelegate {
   public func navigationController(_ navigationController: UINavigationController, willShow viewController: UIViewController, animated: Bool) {
      // check to see if the navigation controller is popping to it's root view controller
      guard let rootViewController = rootViewController else { fatalError() }
      let previousDelegate = previousContextDelegate
      
      if _conductorIsBeingPoppedOffContext(byShowing: viewController) {
         conductorWillDismiss(from: navigationController)
      }
      
      if !_isShowing, rootViewController == viewController {
         conductorWillShow(in: navigationController)
      }
      
      previousDelegate?.navigationController?(navigationController, willShow: viewController, animated: animated)
   }
   
   public func navigationController(_ navigationController: UINavigationController, didShow viewController: UIViewController, animated: Bool) {
      previousContextDelegate?.navigationController?(navigationController, didShow: viewController, animated: animated)
      guard let rootViewController = rootViewController else { return }
      if !_isShowing, rootViewController == viewController {
         conductorDidShow(in: navigationController)
         _isShowing = true
      }
      
      if _conductorIsBeingPoppedOffContext(byShowing: viewController) {
         _dismiss()
         conductorDidDismiss(from: navigationController)
      }
   }
   
   public func navigationController(_ navigationController: UINavigationController, interactionControllerFor animationController: UIViewControllerAnimatedTransitioning) -> UIViewControllerInteractiveTransitioning? {
      return previousContextDelegate?.navigationController?(navigationController, interactionControllerFor: animationController)
   }
   
   public func navigationController(_ navigationController: UINavigationController, animationControllerFor operation: UINavigationControllerOperation, from fromVC: UIViewController, to toVC: UIViewController) -> UIViewControllerAnimatedTransitioning? {
      return previousContextDelegate?.navigationController?(navigationController, animationControllerFor: operation, from: fromVC, to: toVC)
   }
   
   private func _conductorIsBeingPoppedOffContext(byShowing viewController: UIViewController) -> Bool {
      guard _isShowing else { return false }
      guard let rootViewController = rootViewController else { fatalError() }
      guard let rootViewControllerIndex = context?.viewControllers.index(of: rootViewController) else { return true }
      guard let showingViewControllerIndex = context?.viewControllers.index(of: viewController) else { return false }
      
      return showingViewControllerIndex < rootViewControllerIndex
   }
}