//
//  movietransitions.swift
//  Bunk1SpotlightReelMaker
//
//  Created by Peter Kamm on 9/14/16.
//  Copyright © 2016 Spotlight. All rights reserved.
//


import Foundation
import AVFoundation

@objc class MovieTransitions:NSObject {
    // Set the transition duration time to two seconds.
    let transDuration = CMTimeMake(1, 1)
    
    // The movies below have the same dimensions as the movie I want to generate
    let movieSize = CGSizeMake(960, 540)
    
    // This is the preset applied to the AVAssetExportSession.
    // If the passthrough preset is used then the created movie file has two video
    // tracks but the transitions between the segments in each track are lost.
    // Other presets will generate a file with a single video track with the
    // transitions applied before export happens.
     //let exportPreset = AVAssetExportPresetPassthrough
//    let exportPreset = AVAssetExportPreset1280x720
    let exportPreset = AVAssetExportPreset960x540
  
    // Path and file name to where the generated movie file will be created.
    // If a previous file was at this location it will be deleted before the new
    // file is generated. BEWARE
 //   let exportFilePath:NSString = "~/Desktop/TransitionsMovie.mov"
    

    func makeTheMovies(movieAssets: [AVURLAsset], name: String) {
        
        let composition = AVMutableComposition()
        // Now call the functions to do the preperation work for preparing a composition to export.
        // First create the tracks needed for the composition.
        self.buildCompositionTracks(composition, transitionDuration: transDuration, assetsWithVideoTracks: movieAssets)
        //
        //// Create the passthru and transition time ranges.
        let timeRanges = calculateTimeRanges(transDuration, assetsWithVideoTracks: movieAssets)
        //
        //// Create the instructions for which movie to show and create the video composition.
        let videoComposition = buildVideoCompositionAndInstructions(composition,
            passThroughTimeRanges: timeRanges.passThroughTimeRanges,
            transitionTimeRanges: timeRanges.transitionTimeRanges,
            renderSize: movieSize)
        //
        //// Make the export session object that we'll use to export the transition movie
        let exportSession = makeExportSession(exportPreset,
                                              videoComposition: videoComposition,
                                              composition: composition)
        

        
        // Make a expanded file path for export. Delete any previous generated file.
        //let expandedFilePath = NSTemporaryDirectory().stringByAppendingString("transy.mov")
        
        let path = NSSearchPathForDirectoriesInDomains(.DocumentDirectory, .UserDomainMask, true)[0] as String
        let url = NSURL(fileURLWithPath: path)
        let filePath = url.URLByAppendingPathComponent(name+".mov")!.path!
        let fileManager = NSFileManager.defaultManager()
        if fileManager.fileExistsAtPath(filePath) {
            do {
                print("file here, erasing")
                try NSFileManager.defaultManager().removeItemAtPath(filePath)
            } catch {
                print("oops!")
            }
        }
        // Assign the output URL built from the expanded output file path.
        exportSession.outputURL = NSURL(fileURLWithPath:filePath)
        
        // Since export happens asyncrhonously then this command line tool can exit
        // before the export has completed unless we wait until the export has finished.
        let sessionWaitSemaphore = dispatch_semaphore_create(0)
        exportSession.exportAsynchronouslyWithCompletionHandler({
            dispatch_semaphore_signal(sessionWaitSemaphore)
            return Void()
        })
        dispatch_semaphore_wait(sessionWaitSemaphore, DISPATCH_TIME_FOREVER)
        
        if (exportSession.error != nil) {
            print(exportSession.error)
        } else {
            print("Export finished at " + filePath)
        }
    }
    
    // Make movie assets from the URLs.
    //let movieAssets:[AVURLAsset] = urls.map { AVURLAsset(URL:$0, options:.None) }
    
    // Create the mutable composition that we are going to build up.
    //var composition = AVMutableComposition()
    
    // Function to build the composition tracks.
    func buildCompositionTracks(composition: AVMutableComposition, transitionDuration: CMTime, assetsWithVideoTracks: [AVURLAsset]) -> Void {
        let compositionTrackA = composition.addMutableTrackWithMediaType(AVMediaTypeVideo,
                                                                         preferredTrackID: CMPersistentTrackID(kCMPersistentTrackID_Invalid))
        
        let compositionTrackB = composition.addMutableTrackWithMediaType(AVMediaTypeVideo,
                                                                         preferredTrackID: CMPersistentTrackID(kCMPersistentTrackID_Invalid))
        
        let videoTracks = [compositionTrackA, compositionTrackB]
        
        var cursorTime = kCMTimeZero
        
        for (var i = 0 ; i < assetsWithVideoTracks.count ; ++i) {
            let trackIndex = i % 2
            let currentTrack = videoTracks[trackIndex]
            if assetsWithVideoTracks[i].tracksWithMediaType(AVMediaTypeVideo).count > 0 {
                let assetTrack = assetsWithVideoTracks[i].tracksWithMediaType(AVMediaTypeVideo)[0]
                let timeRange = CMTimeRangeMake(kCMTimeZero, assetsWithVideoTracks[i].duration)
                do {
                    try currentTrack.insertTimeRange( timeRange,
                                                      ofTrack: assetTrack,
                                                      atTime: cursorTime)
                } catch {
                    print("Something went wrong!")
                }
                
                cursorTime = CMTimeAdd(cursorTime, assetsWithVideoTracks[i].duration)
                cursorTime = CMTimeSubtract(cursorTime, transitionDuration)
            } else {
                print("fuck")
            }
        }
        
        // Currently leaving out voice overs and movie tracks. // 5
    }
    
    // Function to calculate both the pass through time and the transition time ranges
    func calculateTimeRanges(transitionDuration: CMTime, assetsWithVideoTracks: [AVURLAsset]) ->  (passThroughTimeRanges: [NSValue], transitionTimeRanges: [NSValue]){
        
        var passThroughTimeRanges:[NSValue] = [NSValue]()
        var transitionTimeRanges:[NSValue] = [NSValue]()
        var cursorTime = kCMTimeZero
        
        for (var i = 0 ; i < assetsWithVideoTracks.count ; ++i)
        {
            let asset = assetsWithVideoTracks[i]
            var timeRange = CMTimeRangeMake(cursorTime, asset.duration)
            
            if i > 0 {
                timeRange.start = CMTimeAdd(timeRange.start, transDuration)
                timeRange.duration = CMTimeSubtract(timeRange.duration, transDuration)
            }
            
            if i + 1 < assetsWithVideoTracks.count {
                timeRange.duration = CMTimeSubtract(timeRange.duration, transDuration)
            }
            
            passThroughTimeRanges.append(NSValue(CMTimeRange: timeRange))
            cursorTime = CMTimeAdd(cursorTime, asset.duration)
            cursorTime = CMTimeSubtract(cursorTime, transDuration)
            print("cursorTime.value: \(cursorTime.value)")
            print("cursorTime.timescale: \(cursorTime.timescale)")
            
            if i + 1 < assetsWithVideoTracks.count {
                timeRange = CMTimeRangeMake(cursorTime, transDuration)
                 print("timeRange start value: \(timeRange.start.value)")
                 print("timeRange start timescale: \(timeRange.start.timescale)")
                transitionTimeRanges.append(NSValue(CMTimeRange: timeRange))
            }
        }
        return (passThroughTimeRanges, transitionTimeRanges)
    }
    
    // Build the video composition and instructions.
    func buildVideoCompositionAndInstructions( composition: AVMutableComposition, passThroughTimeRanges: [NSValue], transitionTimeRanges: [NSValue], renderSize: CGSize) -> AVMutableVideoComposition {
        
        // Create a mutable composition instructions object
        var compositionInstructions = [AVMutableVideoCompositionInstruction]()
        
        // Get the list of asset tracks and tell compiler they are a list of asset tracks.
        let tracks = composition.tracksWithMediaType(AVMediaTypeVideo)
        
        // Create a video composition object
        let videoComposition = AVMutableVideoComposition(propertiesOfAsset: composition)
        
        // Now create the instructions from the various time ranges.
        for (var i = 0 ; i < passThroughTimeRanges.count ; ++i)
        {
            let trackIndex = i % 2
            let currentTrack = tracks[trackIndex]
            let instruction = AVMutableVideoCompositionInstruction()
            
            if videoComposition.isValidForAsset(nil, timeRange: passThroughTimeRanges[i].CMTimeRangeValue, validationDelegate: nil){
                print("looks ok")
            } else {
                print("shit")
            }
            
            instruction.timeRange = passThroughTimeRanges[i].CMTimeRangeValue
            
            let layerInstruction = AVMutableVideoCompositionLayerInstruction( assetTrack: currentTrack)
            instruction.layerInstructions = [layerInstruction]
            compositionInstructions.append(instruction)
            
            if i < transitionTimeRanges.count {
                let instruction = AVMutableVideoCompositionInstruction()
                if videoComposition.isValidForAsset(nil, timeRange: transitionTimeRanges[i].CMTimeRangeValue, validationDelegate: nil){
                    print("looks ok")
                } else {
                    print("shit")
                }
                instruction.timeRange = transitionTimeRanges[i].CMTimeRangeValue
                
                // Determine the foreground and background tracks.
                let fgTrack = tracks[trackIndex]
                let bgTrack = tracks[1 - trackIndex]
                
                // Create the "from layer" instruction.
                let fLInstruction = AVMutableVideoCompositionLayerInstruction(
                    assetTrack: fgTrack)
                
                // Make the opacity ramp and apply it to the from layer instruction.
                fLInstruction.setOpacityRampFromStartOpacity(1.0, toEndOpacity:0.0,
                                                             timeRange: instruction.timeRange)
                
                // Create the "to layer" instruction. Do I need this?
                let tLInstruction = AVMutableVideoCompositionLayerInstruction(
                    assetTrack: bgTrack)
                instruction.layerInstructions = [fLInstruction, tLInstruction]
                compositionInstructions.append(instruction)
            }
        }
        videoComposition.instructions = compositionInstructions
        videoComposition.renderSize = renderSize
        videoComposition.frameDuration = CMTimeMake(1, 30)
       // videoComposition.renderScale = 1.0 // This is a iPhone only option.
        return videoComposition
    }
    
    func makeExportSession(preset: String, videoComposition: AVMutableVideoComposition, composition: AVMutableComposition) -> AVAssetExportSession {
        let session = AVAssetExportSession(asset: composition, presetName: preset)
        session!.videoComposition = videoComposition.copy() as? AVVideoComposition
        // session.outputFileType = "com.apple.m4v-video"
        // session.outputFileType = AVFileTypeAppleM4V
        session!.outputFileType = AVFileTypeQuickTimeMovie
        return session!
    }
    
    // Now call the functions to do the preperation work for preparing a composition to export.
    // First create the tracks needed for the composition.
    //buildCompositionTracks(composition, transitionDuration: transDuration, assetsWithVideoTracks: movieAssets)
    //
    //// Create the passthru and transition time ranges.
    //let timeRanges = calculateTimeRanges(transitionDuration: transDuration,
    //                                     assetsWithVideoTracks: movieAssets)
    //
    //// Create the instructions for which movie to show and create the video composition.
    //let videoComposition = buildVideoCompositionAndInstructions(
    //    composition: composition,
    //    passThroughTimeRanges: timeRanges.passThroughTimeRanges,
    //    transitionTimeRanges: timeRanges.transitionTimeRanges,
    //    renderSize: movieSize)
    //
    //// Make the export session object that we'll use to export the transition movie
    //let exportSession = makeExportSession(preset: exportPreset,
    //                                      videoComposition: videoComposition,
    //                                      composition: composition)
    //
    //// Make a expanded file path for export. Delete any previous generated file.
    //let expandedFilePath = exportFilePath.stringByExpandingTildeInPath
    //NSFileManager.defaultManager().removeItemAtPath(expandedFilePath, error: nil)
    //
    //// Assign the output URL built from the expanded output file path.
    //exportSession.outputURL = NSURL(fileURLWithPath: expandedFilePath, isDirectory:false)!
    //
    //// Since export happens asyncrhonously then this command line tool can exit
    //// before the export has completed unless we wait until the export has finished.
    //let sessionWaitSemaphore = dispatch_semaphore_create(0)
    //exportSession.exportAsynchronouslyWithCompletionHandler({
    //    dispatch_semaphore_signal(sessionWaitSemaphore)
    //    return Void()
    //})
    //dispatch_semaphore_wait(sessionWaitSemaphore, DISPATCH_TIME_FOREVER)
    //
    //println("Export finished")
}
