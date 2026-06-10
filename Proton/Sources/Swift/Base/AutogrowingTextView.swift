//
//  AutogrowingTextView.swift
//  Proton
//
//  Created by Rajdeep Kwatra on 31/12/19.
//  Copyright © 2019 Rajdeep Kwatra. All rights reserved.
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//    http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//

import Foundation
import UIKit

class AutogrowingTextView: UITextView {

    var maxHeight: CGFloat = 0
    private var allowAutogrowing: Bool
    weak var boundsObserver: BoundsObserving?
    private var maxHeightConstraint: NSLayoutConstraint!
    private var heightAnchorConstraint: NSLayoutConstraint?
    private var isSizeRecalculationRequired = true
    private var lastHeightCalculationKey: HeightCalculationKey?
    private var lastCalculatedSize: CGSize?
    private static let largeTextMeasurementThreshold = 20_000
    
    let lineSpacing = 29.0

    init(frame: CGRect = .zero, textContainer: NSTextContainer? = nil, allowAutogrowing: Bool = false) {
        self.allowAutogrowing = allowAutogrowing
        super.init(frame: frame, textContainer: textContainer)
        isScrollEnabled = false
        addHeightConstraint()
        contentMode = .redraw
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func setAutogrowing(_ isAutogrowing: Bool) {
        guard allowAutogrowing != isAutogrowing else { return }
        allowAutogrowing = isAutogrowing
        lastHeightCalculationKey = nil
        lastCalculatedSize = nil

        if allowAutogrowing {
            addHeightConstraint()
            recalculateHeight()
        } else {
            isScrollEnabled = false
            if let heightAnchorConstraint = heightAnchorConstraint {
                NSLayoutConstraint.deactivate([heightAnchorConstraint])
            }
            heightAnchorConstraint = nil
        }
    }

    private func addHeightConstraint() {
        guard allowAutogrowing, heightAnchorConstraint == nil else { return }
        let heightConstraint = heightAnchor.constraint(greaterThanOrEqualToConstant: contentSize.height)
        heightConstraint.priority = .defaultHigh
        heightAnchorConstraint = heightConstraint
        NSLayoutConstraint.activate([heightConstraint])
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        
        guard allowAutogrowing, maxHeight != .greatestFiniteMagnitude else { return }
        // Required to reset the size if content is removed
        if contentSize.height <= frame.height, isEditable {
            recalculateHeight()
            invalidateIntrinsicContentSize()
            return
        }

        guard isSizeRecalculationRequired else { return }
        isSizeRecalculationRequired = false
        recalculateHeight()
    }

    func recalculateHeight(size: CGSize? = nil) {
        guard allowAutogrowing else { return }
        let bounds = self.bounds.integral
        let sizeToUse = size ?? frame.size
        let fittingSize = self.calculatedSize(attributedText: attributedText, frame: sizeToUse, textContainerInset: textContainerInset)
        self.isScrollEnabled = (fittingSize.height > bounds.height) || (self.maxHeight > 0 && self.maxHeight < fittingSize.height)
        heightAnchorConstraint?.constant = min(fittingSize.height, contentSize.height)
    }

    override open func sizeThatFits(_ size: CGSize) -> CGSize {
        var fittingSize = calculatedSize(attributedText: attributedText, frame: size, textContainerInset: textContainerInset)
        if maxHeight > 0 {
            fittingSize.height = min(maxHeight, fittingSize.height)
        }
        return fittingSize
    }

    override var bounds: CGRect {
        didSet {
            guard ceil(oldValue.height) != ceil(bounds.height) else { return }
            boundsObserver?.didChangeBounds(bounds, oldBounds: oldValue)
            isSizeRecalculationRequired = true
        }
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        self.becomeFirstResponder()
    }

    private func calculatedSize(attributedText: NSAttributedString, frame: CGSize, textContainerInset: UIEdgeInsets) -> CGSize {
        let horizontalAdjustments = (textContainer.lineFragmentPadding * 2) + (textContainerInset.left + textContainerInset.right)
        let measuringWidth = max(0, frame.width - horizontalAdjustments)
        let calculationKey = HeightCalculationKey(
            width: measuringWidth.rounded(.up),
            textLength: attributedText.length,
            contentHeight: contentSize.height.rounded(.up),
            inset: textContainerInset
        )

        if calculationKey == lastHeightCalculationKey, let cachedSize = lastCalculatedSize {
            return cachedSize
        }

        let isMeasuringCurrentWidth = abs(frame.width.rounded(.up) - bounds.width.rounded(.up)) <= 1
        if attributedText.length > Self.largeTextMeasurementThreshold,
           isMeasuringCurrentWidth,
           contentSize.height > 0 {
            let calculatedSize = CGSize(width: frame.width, height: contentSize.height)
            lastHeightCalculationKey = calculationKey
            lastCalculatedSize = calculatedSize
            return calculatedSize
        }

        // Adjust for horizontal paddings in textview to exclude from overall available width for attachment
        let boundingRect = attributedText.boundingRect(with: CGSize(width: measuringWidth, height: .greatestFiniteMagnitude), options: [.usesLineFragmentOrigin], context: nil).integral

        let insets = UIEdgeInsets(top: -textContainerInset.top, left: -textContainerInset.left, bottom: -textContainerInset.bottom, right: -textContainerInset.right)
        let calculatedSize = boundingRect.inset(by: insets).size
        lastHeightCalculationKey = calculationKey
        lastCalculatedSize = calculatedSize
        return calculatedSize
    }
    
}

private struct HeightCalculationKey: Equatable {
    let width: CGFloat
    let textLength: Int
    let contentHeight: CGFloat
    let inset: UIEdgeInsets
}
