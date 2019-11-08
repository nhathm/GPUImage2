//
//  CVPixelBufferInput.swift
//  GPUImage
//
//  Created by NhatHM on 10/25/19.
//  Copyright © 2019 Sunset Lake Software LLC. All rights reserved.
//

import CoreVideo
import CoreMedia

public class CVPixelBufferInput: ImageSource {
    public let targets = TargetContainer()
    public var pixelBufferInput: CVPixelBuffer? {
        didSet {
            handlePixelBufferInput(pixelBufferInput)
        }
    }
    
    private var frameBufferGenerator: FrameBufferGenerator
    
    
    public init() {
        frameBufferGenerator = FrameBufferGenerator()
    }
    
    public func process(_ pixelBuffer: CVPixelBuffer, with frameTime: CMTime, and orientation: ImageOrientation) {
        if let frameBuffer = frameBufferGenerator.generateFromYUVBuffer(pixelBuffer, frameTime: frameTime, videoOrientation: orientation) {
            updateTargetsWithFramebuffer(frameBuffer)
        }
    }
    
    public func transmitPreviousImage(to target: ImageConsumer, atIndex: UInt) {
        
    }
    
    func handlePixelBufferInput(_ pixelBuffer: CVPixelBuffer?) {
        guard let pixelBuffer = pixelBuffer else {
            return
        }
        
        let currentSampleTime = CMTimeMakeWithSeconds(1, 1000)
        process(pixelBuffer, with: currentSampleTime, and: .portrait)
    }
}
