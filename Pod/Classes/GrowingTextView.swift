//
//  GrowingTextView.swift
//  Pods
//
//  Created by Kenneth Tsang on 17/2/2016.
//  Copyright (c) 2016 Kenneth Tsang. All rights reserved.
//

import Foundation
import UIKit

@objc public protocol GrowingTextViewDelegate: UITextViewDelegate {
    @objc optional func textViewDidChangeHeight(_ textView: GrowingTextView, height: CGFloat)
}

@IBDesignable @objc
open class GrowingTextView: UITextView, UITextViewDelegate {
    override open var text: String! {
        didSet { setNeedsDisplay() }
    }
    private weak var heightConstraint: NSLayoutConstraint?
    
    // Maximum length of text. 0 means no limit.
    @IBInspectable open var maxLength: Int = 0
    
    // Trim white space and newline characters when end editing. Default is true
    @IBInspectable open var trimWhiteSpaceWhenEndEditing: Bool = true
    
    // Customization
    @IBInspectable open var minHeight: CGFloat = 0 {
        didSet { forceLayoutSubviews() }
    }
    @IBInspectable open var maxHeight: CGFloat = 0 {
        didSet { forceLayoutSubviews() }
    }
    @IBInspectable open var placeHolder: String? {
        didSet { setNeedsDisplay() }
    }
    @IBInspectable open var placeHolderColor: UIColor = UIColor(white: 0.8, alpha: 1.0) {
        didSet { setNeedsDisplay() }
    }
    @IBInspectable open var placeHolderActiveColor: UIColor = UIColor(white: 0.8, alpha: 1.0) {
        didSet { setNeedsDisplay() }
    }
    @IBInspectable open var cornerRadius: CGFloat = 0 {
        didSet { setNeedsDisplay() }
    }
    @IBInspectable open var borderWidth: CGFloat = 0 {
        didSet { setNeedsDisplay() }
    }
    @IBInspectable open var borderWidthActive: CGFloat = 0 {
        didSet { setNeedsDisplay() }
    }
    @IBInspectable open var borderColor: UIColor = UIColor(white: 0.8, alpha: 1.0) {
        didSet { setNeedsDisplay() }
    }
    @IBInspectable open var borderActiveColor: UIColor = UIColor(white: 0.8, alpha: 1.0) {
        didSet { setNeedsDisplay() }
    }
    @IBInspectable open var attributedPlaceHolder: NSAttributedString? {
        didSet { setNeedsDisplay() }
    }
    @IBInspectable open var placeHolderLeftMargin: CGFloat = 5 {
        didSet { setNeedsDisplay() }
    }
    @IBInspectable public var bottomInset: CGFloat = 0 {
        didSet { setNeedsDisplay() }
    }
    @IBInspectable public var leftInset: CGFloat = 0 {
        didSet { setNeedsDisplay() }
    }
    @IBInspectable public var rightInset: CGFloat = 0 {
        didSet { setNeedsDisplay() }
    }
    @IBInspectable public var topInset: CGFloat = 0 {
        didSet { setNeedsDisplay() }
    }
    @IBInspectable public var centerText: Bool = true {
        didSet { setNeedsDisplay() }
    }
    
    override open var contentSize: CGSize {
        didSet {
            if centerText {
                var topCorrection = (bounds.size.height - contentSize.height * zoomScale) / 2.0
                topCorrection = max(0, topCorrection)
                contentInset = UIEdgeInsets(top: topCorrection, left: 0, bottom: 0, right: 0)
            } else {
                contentInset = UIEdgeInsets(top: topInset, left: leftInset, bottom: bottomInset, right: rightInset)
            }
        }
    }
    
    private var isActive = false
    
    // Initialize
    override public init(frame: CGRect, textContainer: NSTextContainer?) {
        super.init(frame: frame, textContainer: textContainer)
        commonInit()
    }
    
    required public init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        commonInit()
    }
    
    private func commonInit() {
        contentMode = .redraw
        associateConstraints()
        NotificationCenter.default.addObserver(self, selector: #selector(textDidChange), name: .UITextViewTextDidChange, object: self)
        NotificationCenter.default.addObserver(self, selector: #selector(textDidEndEditing), name: .UITextViewTextDidEndEditing, object: self)
        NotificationCenter.default.addObserver(self, selector: #selector(textDidBeginEditing), name: .UITextViewTextDidBeginEditing, object: self)
        self.autocorrectionType = .no
        self.delegate = self
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    open override var intrinsicContentSize: CGSize {
        return CGSize(width: UIViewNoIntrinsicMetric, height: 30)
    }
    
    func associateConstraints() {
        // iterate through all text view's constraints and identify
        // height,from: https://github.com/legranddamien/MBAutoGrowingTextView
        for constraint in constraints {
            if (constraint.firstAttribute == .height) {
                if (constraint.relation == .equal) {
                    heightConstraint = constraint;
                }
            }
        }
    }
    
    // Calculate and adjust textview's height
    private var oldText: String = ""
    private var oldSize: CGSize = .zero
    
    private func forceLayoutSubviews() {
        oldSize = .zero
        setNeedsLayout()
        layoutIfNeeded()
    }
    
    override open func layoutSubviews() {
        super.layoutSubviews()
        if self.text.isEmpty {
            self.changeHeight("")
        }
        self.layer.shadowColor = UIColor(red: 13/255.0, green: 21/255.0, blue: 38/255.0, alpha: 0.2).cgColor
    }
    
    open func changeHeight(_ string: String) {
        self.textContainerInset = UIEdgeInsetsMake(topInset, leftInset, bottomInset, rightInset)
        
        if text == oldText && bounds.size == oldSize { return }
        oldText = text
        oldSize = bounds.size
        
        let tempTextView = UITextView()
        tempTextView.text = string
        
//        let size = tempTextView.sizeThatFits(CGSize(width: bounds.size.width, height: CGFloat.greatestFiniteMagnitude))
        
        var height = self.inputBarHeigtForLines(numberOfLines())
        
        // Constrain minimum height
        height = minHeight > 0 ? max(height, minHeight) : height
        
        // Constrain maximum height
        height = maxHeight > 0 ? min(height, maxHeight) : height
        
        // Add height constraint if it is not found
        if (heightConstraint == nil) {
            heightConstraint = NSLayoutConstraint(item: self, attribute: .height, relatedBy: .equal, toItem: nil, attribute: .notAnAttribute, multiplier: 1.0, constant: height)
            addConstraint(heightConstraint!)
        }
        
        // Update height constraint if needed
        if height != heightConstraint?.constant {
            heightConstraint!.constant = height
            scrollToCorrectPosition()
            if let delegate = delegate as? GrowingTextViewDelegate {
                delegate.textViewDidChangeHeight?(self, height: height)
            }
        }
    }
    
    func numberOfLines() -> Int {
        var contentSize = self.contentSize
        
        var contentHeight = contentSize.height
        contentHeight -= self.textContainerInset.top + self.textContainerInset.bottom
        
        var lines: Int = Int(fabs(contentHeight/self.font!.lineHeight))
        
        if lines == 1 && contentSize.height > self.bounds.size.height {
            contentSize.height = self.bounds.size.height
            self.contentSize = contentSize
        }
        
        if lines == 0 {
            lines = 1
        }
        
        return lines
    }
    
    func inputBarHeigtForLines(_ lines: Int) -> CGFloat {
        
        var height = self.intrinsicContentSize.height
        print(height)
        height -= self.font!.lineHeight
        height += (self.font!.lineHeight * CGFloat(lines)).rounded()
        return height
    }
    
    private func scrollToCorrectPosition() {
        DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(100)) {
            if self.isFirstResponder {
                self.scrollRangeToVisible(NSMakeRange(-1, 0)) // Scroll to bottom
            } else {
                self.scrollRangeToVisible(NSMakeRange(0, 0)) // Scroll to top
            }
        }
    }
    
    // Show placeholder if needed
    override open func draw(_ rect: CGRect) {
        super.draw(rect)
        
        let xValue = textContainerInset.left + placeHolderLeftMargin
        let yValue = textContainerInset.top
        let width = rect.size.width - xValue - textContainerInset.right
        let height = rect.size.height - yValue - textContainerInset.bottom
        let placeHolderRect = CGRect(x: xValue, y: yValue, width: width, height: height)
        
        self.layer.borderWidth = self.isActive ? self.borderWidthActive : self.borderWidth
        self.layer.borderColor = self.isActive ? self.borderActiveColor.cgColor : self.borderColor.cgColor
        self.layer.shadowOffset = CGSize(width: 0, height: self.isActive ? 5.0 : 0)
        self.layer.shadowOpacity = self.isActive ? 1.0 : 0
        self.layer.cornerRadius = self.cornerRadius
        self.tintColor = self.borderActiveColor
        
        if text.isEmpty {
            if let attributedPlaceholder = attributedPlaceHolder {
                // Prefer to use attributedPlaceHolder
                attributedPlaceholder.draw(in: placeHolderRect)
            } else if let placeHolder = placeHolder {
                // Otherwise user placeHolder and inherit `text` attributes
                let paragraphStyle = NSMutableParagraphStyle()
                paragraphStyle.alignment = textAlignment
                var attributes: [String: Any] = [
                    NSForegroundColorAttributeName: self.isActive ? placeHolderActiveColor : placeHolderColor,
                    NSParagraphStyleAttributeName: paragraphStyle
                ]
                if let font = font {
                    attributes[NSFontAttributeName] = font
                }
                
                placeHolder.draw(in: placeHolderRect, withAttributes: attributes)
            }
        }
    }
    
    func textDidBeginEditing(notification: Notification) {
        if let notificationObject = notification.object as? GrowingTextView {
            if notificationObject === self {
                self.isActive = true
                setNeedsDisplay()
            }
        }
    }
    
    // Trim white space and new line characters when end editing.
    func textDidEndEditing(notification: Notification) {
        if let notificationObject = notification.object as? GrowingTextView {
            if notificationObject === self {
                self.isActive = false
                if trimWhiteSpaceWhenEndEditing {
                    text = text?.trimmingCharacters(in: .whitespacesAndNewlines)
                }
                setNeedsDisplay()
            }
//            scrollToCorrectPosition()
        }
    }
    
    // Limit the length of text
    func textDidChange(notification: Notification) {
        if let notificationObject = notification.object as? GrowingTextView {
            if notificationObject === self {
                if maxLength > 0 && text.characters.count > maxLength {
                    
                    let endIndex = text.index(text.startIndex, offsetBy: maxLength)
                    text = text.substring(to: endIndex)
                    undoManager?.removeAllActions()
                }
                setNeedsDisplay()
            }
        }
    }
    
    //MARK: Custom funcs
    
    open func clearTextView() {
        self.text = ""
        setNeedsDisplay()
    }
    
    public func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
        if let growingTV = textView as? GrowingTextView {
            let result = (textView.text as NSString?)?.replacingCharacters(in: range, with: text) ?? text
            growingTV.changeHeight(result)
        }
        return true
    }
}


