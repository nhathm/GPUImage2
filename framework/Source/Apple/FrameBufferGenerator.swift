//
//  FrameBufferGenerator.swift
//  GPUImage
//
//  Created by NhatHM on 10/25/19.
//  Copyright © 2019 Sunset Lake Software LLC. All rights reserved.
//

import CoreMedia

public class FrameBufferGenerator {
    let yuvConversionShader: ShaderProgram
    
    public init() {
        self.yuvConversionShader = crashOnShaderCompileFailure("FrameBufferGenerator"){
            try sharedImageProcessingContext.programForVertexShader(defaultVertexShaderForInputs(2), fragmentShader:YUVConversionFullRangeFragmentShader)
        }
    }
    
    public func generateFromYUVBuffer(_ yuvPixelBuffer: CVPixelBuffer, frameTime: CMTime, videoOrientation: ImageOrientation) -> Framebuffer? {
        var framebuffer: Framebuffer?
        sharedImageProcessingContext.runOperationSynchronously {
            framebuffer = internalGenerateFromYUVBuffer(yuvPixelBuffer, frameTime: frameTime, videoOrientation: videoOrientation)
        }
        return framebuffer
    }
    
    private func internalGenerateFromYUVBuffer(_ yuvPixelBuffer: CVPixelBuffer, frameTime: CMTime, videoOrientation: ImageOrientation) -> Framebuffer? {
        let bufferHeight = CVPixelBufferGetHeight(yuvPixelBuffer)
        let bufferWidth = CVPixelBufferGetWidth(yuvPixelBuffer)
        let conversionMatrix = colorConversionMatrix601FullRangeDefault
        CVPixelBufferLockBaseAddress(yuvPixelBuffer, CVPixelBufferLockFlags(rawValue: CVOptionFlags(0)))
        defer {
            CVPixelBufferUnlockBaseAddress(yuvPixelBuffer, CVPixelBufferLockFlags(rawValue: CVOptionFlags(0)))
            CVOpenGLESTextureCacheFlush(sharedImageProcessingContext.coreVideoTextureCache, 0)
        }
        
        glActiveTexture(GLenum(GL_TEXTURE0))
        var luminanceGLTexture: CVOpenGLESTexture?
        let luminanceGLTextureResult = CVOpenGLESTextureCacheCreateTextureFromImage(kCFAllocatorDefault, sharedImageProcessingContext.coreVideoTextureCache, yuvPixelBuffer, nil, GLenum(GL_TEXTURE_2D), GL_LUMINANCE, GLsizei(bufferWidth), GLsizei(bufferHeight), GLenum(GL_LUMINANCE), GLenum(GL_UNSIGNED_BYTE), 0, &luminanceGLTexture)
        if luminanceGLTextureResult != kCVReturnSuccess || luminanceGLTexture == nil {
            print("Could not create LuminanceGLTexture")
            return nil
        }
        
        let luminanceTexture = CVOpenGLESTextureGetName(luminanceGLTexture!)
        
        glBindTexture(GLenum(GL_TEXTURE_2D), luminanceTexture)
        glTexParameterf(GLenum(GL_TEXTURE_2D), GLenum(GL_TEXTURE_WRAP_S), GLfloat(GL_CLAMP_TO_EDGE));
        glTexParameterf(GLenum(GL_TEXTURE_2D), GLenum(GL_TEXTURE_WRAP_T), GLfloat(GL_CLAMP_TO_EDGE));
        
        let luminanceFramebuffer: Framebuffer
        do {
            luminanceFramebuffer = try Framebuffer(context: sharedImageProcessingContext,
                                                   orientation: videoOrientation,
                                                   size: GLSize(width: GLint(bufferWidth), height: GLint(bufferHeight)),
                                                   textureOnly: true,
                                                   overriddenTexture: luminanceTexture)
        } catch {
            print("Could not create a framebuffer of the size (\(bufferWidth), \(bufferHeight)), error: \(error)")
            return nil
        }
        
        glActiveTexture(GLenum(GL_TEXTURE1))
        var chrominanceGLTexture: CVOpenGLESTexture?
        let chrominanceGLTextureResult = CVOpenGLESTextureCacheCreateTextureFromImage(kCFAllocatorDefault, sharedImageProcessingContext.coreVideoTextureCache, yuvPixelBuffer, nil, GLenum(GL_TEXTURE_2D), GL_LUMINANCE_ALPHA, GLsizei(bufferWidth / 2), GLsizei(bufferHeight / 2), GLenum(GL_LUMINANCE_ALPHA), GLenum(GL_UNSIGNED_BYTE), 1, &chrominanceGLTexture)
        
        if chrominanceGLTextureResult != kCVReturnSuccess || chrominanceGLTexture == nil {
            print("Could not create ChrominanceGLTexture")
            return nil
        }
        
        let chrominanceTexture = CVOpenGLESTextureGetName(chrominanceGLTexture!)
        
        glBindTexture(GLenum(GL_TEXTURE_2D), chrominanceTexture)
        glTexParameterf(GLenum(GL_TEXTURE_2D), GLenum(GL_TEXTURE_WRAP_S), GLfloat(GL_CLAMP_TO_EDGE));
        glTexParameterf(GLenum(GL_TEXTURE_2D), GLenum(GL_TEXTURE_WRAP_T), GLfloat(GL_CLAMP_TO_EDGE));
        
        let chrominanceFramebuffer: Framebuffer
        do {
            chrominanceFramebuffer = try Framebuffer(context: sharedImageProcessingContext,
                                                     orientation: videoOrientation,
                                                     size: GLSize(width:GLint(bufferWidth), height:GLint(bufferHeight)),
                                                     textureOnly: true,
                                                     overriddenTexture: chrominanceTexture)
        } catch {
            print("Could not create a framebuffer of the size (\(bufferWidth), \(bufferHeight)), error: \(error)")
            return nil
        }
        
        let portraitSize: GLSize
        switch videoOrientation.rotationNeededForOrientation(.portrait) {
        case .noRotation, .rotate180, .flipHorizontally, .flipVertically:
            portraitSize = GLSize(width: GLint(bufferWidth), height: GLint(bufferHeight))
        case .rotateCounterclockwise, .rotateClockwise, .rotateClockwiseAndFlipVertically, .rotateClockwiseAndFlipHorizontally:
            portraitSize = GLSize(width: GLint(bufferHeight), height: GLint(bufferWidth))
        }
        
        let framebuffer = sharedImageProcessingContext.framebufferCache.requestFramebufferWithProperties(orientation: .portrait, size: portraitSize, textureOnly: false)
        
        convertYUVToRGB(shader: yuvConversionShader,
                        luminanceFramebuffer: luminanceFramebuffer,
                        chrominanceFramebuffer: chrominanceFramebuffer,
                        resultFramebuffer: framebuffer,
                        colorConversionMatrix: conversionMatrix)
        framebuffer.timingStyle = .videoFrame(timestamp: Timestamp(frameTime))
        return framebuffer
    }
}
