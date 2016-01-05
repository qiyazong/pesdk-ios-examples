//
//  TextFilter.swift
//  imglyKit
//
//  Created by Carsten Przyluczky on 05/03/15.
//  Copyright (c) 2015 9elements GmbH. All rights reserved.
//

#if os(iOS)
import CoreImage
import UIKit
#elseif os(OSX)
import QuartzCore
import AppKit
#endif

@objc(IMGLYTextFilter) public class TextFilter: CIFilter, Filter {
    /// A CIImage object that serves as input for the filter.
    public var inputImage: CIImage?

    /// The sticker that should be rendered.
    #if os(iOS)
    public var sticker: UIImage? {
        return createTextImage()
    }
    #elseif os(OSX)
    public var sticker: NSImage? {
        return createTextImage()
    }
    #endif

    /// The text that should be rendered.
    public var text = ""

    /// The name of the used font.
    public var fontName = "Helvetica Neue"
    ///  This factor determins the font-size. Its a relative value that is multiplied with the image height
    ///  during the process.
    public var initialFontSize = CGFloat(1)

    public var transform = CGAffineTransformIdentity

    /// The relative center of the sticker within the image.
    public var center = CGPoint()

    /// The relative scale of the sticker within the image.
    public var scale = CGFloat(1.0)

    /// The crop-create applied to the input image, so we can adjust the sticker position
    public var cropRect = CGRect(x: 0, y: 0, width: 1, height: 1)

    /// The color of the text.
    #if os(iOS)
    public var color = UIColor.whiteColor()
    #elseif os(OSX)
    public var color = NSColor.whiteColor()
    #endif

    override init() {
        super.init()
    }

    required public init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }

    /// Returns a CIImage object that encapsulates the operations configured in the filter. (read-only)
    public override var outputImage: CIImage? {
        guard let inputImage = inputImage else {
            return nil
        }

        if text.isEmpty {
            return inputImage
        }

        let stickerImage = createStickerImage()

        guard let cgImage = stickerImage.CGImage, filter = CIFilter(name: "CISourceOverCompositing") else {
            return inputImage
        }

        let stickerCIImage = CIImage(CGImage: cgImage)
        filter.setValue(inputImage, forKey: kCIInputBackgroundImageKey)
        filter.setValue(stickerCIImage, forKey: kCIInputImageKey)
        return filter.outputImage
    }

    public func absolutStickerSizeForImageSize(imageSize: CGSize) -> CGSize {
        let stickerRatio = sticker!.size.height / sticker!.size.width
        if imageSize.width > imageSize.height {
            return CGSize(width: self.scale * imageSize.height, height: self.scale * stickerRatio * imageSize.height)
        }
        return CGSize(width: self.scale * imageSize.width, height: self.scale * stickerRatio * imageSize.width)
    }

    #if os(iOS)

    private func createTextImage() -> UIImage {
        let rect = inputImage!.extent
        let imageSize = rect.size

        let originalSize = CGSize(width: round(imageSize.width / cropRect.width), height: round(imageSize.height / cropRect.height))

        // swiftlint:disable force_cast
        let customParagraphStyle = NSMutableParagraphStyle.defaultParagraphStyle().mutableCopy() as! NSMutableParagraphStyle
        // swiftlint:enable force_cast
        customParagraphStyle.lineBreakMode = .ByClipping

        let textSize = textImageSize()
        let context = UIGraphicsGetCurrentContext()
        CGContextSaveGState(context)
        UIGraphicsBeginImageContext(textSize)
        UIColor(white: 1.0, alpha: 0.0).setFill()
        UIRectFill(CGRect(origin: CGPoint(), size: textSize))

        if let font = UIFont(name: fontName, size: initialFontSize * originalSize.height), paragraphStyle = customParagraphStyle.copy() as? NSParagraphStyle {
            text.drawAtPoint(CGPointZero, withAttributes: [NSFontAttributeName: font, NSForegroundColorAttributeName: color, NSParagraphStyleAttributeName: paragraphStyle])
        }

        let image = UIGraphicsGetImageFromCurrentImageContext()
        CGContextRestoreGState(context)
        UIGraphicsEndImageContext()

        return image
    }

    #elseif os(OSX)

    private func createTextImage() -> NSImage {
        let rect = inputImage!.extent
        let imageSize = rect.size

        let originalSize = CGSize(width: round(imageSize.width / cropRect.width), height: round(imageSize.height / cropRect.height))

        // swiftlint:disable force_cast
        let customParagraphStyle = NSMutableParagraphStyle.defaultParagraphStyle().mutableCopy() as! NSMutableParagraphStyle
        // swiftlint:enable force_cast
        customParagraphStyle.lineBreakMode = .ByClipping

        let textSize = textImageSize()
        let image = NSImage(size: textSize)
        image.lockFocus()

        NSColor(white: 1, alpha: 0).setFill()
        NSRectFill(CGRect(origin: CGPoint(), size: textSize))

        if let font = NSFont(name: fontName, size: initialFontSize * originalSize.height), paragraphStyle = customParagraphStyle.copy() as? NSParagraphStyle {
            text.drawAtPoint(CGPointZero, withAttributes: [NSFontAttributeName: font, NSForegroundColorAttributeName: color, NSParagraphStyleAttributeName: paragraphStyle])
        }

        image.unlockFocus()

        return image
    }

    #endif

    public func textImageSize() -> CGSize {
        let rect = inputImage!.extent
        let imageSize = rect.size

        let originalSize = CGSize(width: round(imageSize.width / cropRect.width), height: round(imageSize.height / cropRect.height))
        // swiftlint:disable force_cast
        let customParagraphStyle = NSMutableParagraphStyle.defaultParagraphStyle().mutableCopy() as! NSMutableParagraphStyle
        // swiftlint:enable force_cast
        customParagraphStyle.lineBreakMode = .ByClipping

        #if os(iOS)
        guard let font = UIFont(name: fontName, size: initialFontSize * originalSize.height), paragraphStyle = customParagraphStyle.copy() as? NSParagraphStyle else {
            return CGSizeZero
        }
        #elseif os(OSX)
        guard let font = NSFont(name: fontName, size: initialFontSize * originalSize.height), paragraphStyle = customParagraphStyle.copy() as? NSParagraphStyle else {
            return CGSizeZero
        }
        #endif

        return text.sizeWithAttributes([NSFontAttributeName: font, NSForegroundColorAttributeName: color, NSParagraphStyleAttributeName: paragraphStyle])
    }

    #if os(iOS)

    private func createStickerImage() -> UIImage {
        let rect = inputImage!.extent
        let imageSize = rect.size
        UIGraphicsBeginImageContext(imageSize)
        UIColor(white: 1.0, alpha: 0.0).setFill()
        UIRectFill(CGRect(origin: CGPoint(), size: imageSize))

        if let context = UIGraphicsGetCurrentContext() {
            drawStickerInContext(context, withImageOfSize: imageSize)
        }

        let image = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()

        return image
    }

    #elseif os(OSX)

    private func createStickerImage() -> NSImage {
        let rect = inputImage!.extent
        let imageSize = rect.size
        let image = NSImage(size: imageSize)
        image.lockFocus()

        NSColor(white: 1, alpha: 0).setFill()
        NSRectFill(CGRect(origin: CGPoint(), size: imageSize))

        if let context = NSGraphicsContext.currentContext()?.CGContext {
            drawStickerInContext(context, withImageOfSize: imageSize)
        }

        image.unlockFocus()

        return image
    }

    #endif

    private func drawStickerInContext(context: CGContextRef, withImageOfSize imageSize: CGSize) {
        CGContextSaveGState(context)

        let originalSize = CGSize(width: round(imageSize.width / cropRect.width), height: round(imageSize.height / cropRect.height))
        var center = CGPoint(x: self.center.x * originalSize.width, y: self.center.y * originalSize.height)
        center.x -= (cropRect.origin.x * originalSize.width)
        center.y -= (cropRect.origin.y * originalSize.height)

        let size = self.absolutStickerSizeForImageSize(originalSize)
        let imageRect = CGRect(origin: center, size: size)

        // Move center to origin
        CGContextTranslateCTM(context, imageRect.origin.x, imageRect.origin.y)
        // Apply the transform
        CGContextConcatCTM(context, self.transform)
        // Move the origin back by half
        CGContextTranslateCTM(context, imageRect.size.width * -0.5, imageRect.size.height * -0.5)

        sticker?.drawInRect(CGRect(origin: CGPoint(), size: size))
        CGContextRestoreGState(context)
    }

  }

extension TextFilter {
    public override func copyWithZone(zone: NSZone) -> AnyObject {
        // swiftlint:disable force_cast
        let copy = super.copyWithZone(zone) as! TextFilter
        copy.inputImage = inputImage?.copyWithZone(zone) as? CIImage
        copy.text = (text as NSString).copyWithZone(zone) as! String
        copy.fontName = (fontName as NSString).copyWithZone(zone) as! String
        copy.initialFontSize = initialFontSize
        copy.cropRect = cropRect
        copy.center = center
        copy.scale = scale
        copy.transform = transform
        #if os(iOS)
        copy.color = color.copyWithZone(zone) as! UIColor
        #elseif os(OSX)
        copy.color = color.copyWithZone(zone) as! NSColor
        #endif
        // swiftlint:enable force_cast

        return copy
    }
}