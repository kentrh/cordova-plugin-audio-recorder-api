#import "AudioRecorderAPI.h"
#import <Cordova/CDV.h>

@implementation AudioRecorderAPI

#define RECORDINGS_FOLDER [NSHomeDirectory() stringByAppendingPathComponent:@"Documents"]

#define ERROR_PERMISSION_DENIED 1

- (void)prepareForRecord:(CDVInvokedUrlCommand *)command
{
    _command = command;
    
    [self.commandDelegate runInBackground:^{
        AVAudioSession *audioSession = [AVAudioSession sharedInstance];
        
        NSError *err;
        [audioSession setCategory:AVAudioSessionCategoryPlayAndRecord error:&err];
        if (err)
        {
            NSLog(@"%@ %ld %@", [err domain], (long)[err code], [[err userInfo] description]);
        }
        
        err = nil;
        [audioSession setActive:YES error:&err];
        
        if (err)
        {
            NSLog(@"%@ %ld %@", [err domain], (long)[err code], [[err userInfo] description]);
        }
        hasPrepared = YES;
        NSLog(@"prepeared for recording");
    }];
}

- (void)record:(CDVInvokedUrlCommand*)command {
    _command = command;
    duration = [_command.arguments objectAtIndex:0];
    
    [self.commandDelegate runInBackground:^{
        
        AVAudioSession *audioSession = [AVAudioSession sharedInstance];
        
        [audioSession requestRecordPermission:^(BOOL granted) {
            if (granted) {
                NSError *err;
                if (!hasPrepared) {
                    
                    [audioSession setCategory:AVAudioSessionCategoryPlayAndRecord error:&err];
                    if (err)
                    {
                        NSLog(@"%@ %ld %@", [err domain], (long)[err code], [[err userInfo] description]);
                    }
                    
                    err = nil;
                    [audioSession setActive:YES error:&err];
                    
                    if (err)
                    {
                        NSLog(@"%@ %ld %@", [err domain], (long)[err code], [[err userInfo] description]);
                    }
                }
                
                NSMutableDictionary *recordSettings = [[NSMutableDictionary alloc] init];
                [recordSettings setValue:[NSNumber numberWithInt:kAudioFormatMPEG4AAC] forKey:AVFormatIDKey];
                [recordSettings setValue:[NSNumber numberWithFloat:44100.0] forKey:AVSampleRateKey];
                [recordSettings setValue:[NSNumber numberWithInt: 1] forKey:AVNumberOfChannelsKey];
                [recordSettings setValue:[NSNumber numberWithInt:16] forKey:AVLinearPCMBitDepthKey];
                [recordSettings setValue:[NSNumber numberWithBool:NO] forKey:AVLinearPCMIsBigEndianKey];
                [recordSettings setValue:[NSNumber numberWithBool:NO] forKey:AVLinearPCMIsFloatKey];
                
                // Create a new dated file
                NSString *uuid = [[NSUUID UUID] UUIDString];
                recorderFilePath = [NSString stringWithFormat:@"%@/%@.m4a", RECORDINGS_FOLDER, uuid];
                NSLog(@"recording file path: %@", recorderFilePath);
                
                NSURL *url = [NSURL fileURLWithPath:recorderFilePath];
                err = nil;
                recorder = [[AVAudioRecorder alloc] initWithURL:url settings:recordSettings error:&err];
                if(!recorder){
                    NSLog(@"recorder: %@ %ld %@", [err domain], (long)[err code], [[err userInfo] description]);
                    return;
                }
                
                [recorder setDelegate:self];
                
                if (![recorder prepareToRecord]) {
                    NSLog(@"prepareToRecord failed");
                    return;
                }
                
                if (![recorder recordForDuration:(NSTimeInterval)[duration intValue]]) {
                    NSLog(@"recordForDuration failed");
                    return;
                }

            } else {
                NSLog(@"Permission to microphone denied");
                pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsInt:ERROR_PERMISSION_DENIED];
                [self.commandDelegate sendPluginResult:pluginResult callbackId:_command.callbackId];
            }
        }];
        
    }];
}

- (void)stop:(CDVInvokedUrlCommand*)command {
    _command = command;
    if ([recorder isRecording]) {
        NSLog(@"stopRecording");
        [recorder stop];
    }
    
    if (player != nil && [player isPlaying]) {
        NSLog(@"stopPlaying");
        [player stop];
    }
    
    NSLog(@"stopped");
}

- (void)playback:(CDVInvokedUrlCommand*)command {
    _command = command;
    [self.commandDelegate runInBackground:^{
        NSLog(@"recording playback");
        NSURL *url = [NSURL fileURLWithPath:recorderFilePath];
        NSError *err;
        player = [[AVAudioPlayer alloc] initWithContentsOfURL:url error:&err];
        player.numberOfLoops = 0;
        player.delegate = self;
        [player prepareToPlay];
        [player play];
        if (err) {
            NSLog(@"%@ %ld %@", [err domain], (long)[err code], [[err userInfo] description]);
        }
        NSLog(@"playing");
    }];
}

- (void)audioPlayerDidFinishPlaying:(AVAudioPlayer *)player successfully:(BOOL)flag {
    NSLog(@"audioPlayerDidFinishPlaying");
    pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:@"playbackComplete"];
    [self.commandDelegate sendPluginResult:pluginResult callbackId:_command.callbackId];
}

- (void)audioRecorderDidFinishRecording:(AVAudioRecorder *)recorder successfully:(BOOL)flag {
    hasPrepared = NO;
    AVAudioSession *audioSession = [AVAudioSession sharedInstance];
    NSError *err;
    
    [audioSession setCategory:AVAudioSessionCategoryPlayback error:&err];
    if (err)
    {
        NSLog(@"%@ %ld %@", [err domain], (long)[err code], [[err userInfo] description]);
    }
    
    NSURL *url = [NSURL fileURLWithPath: recorderFilePath];
    err = nil;
    NSData *audioData = [NSData dataWithContentsOfFile:[url path] options: 0 error:&err];
    if(!audioData) {
        NSLog(@"audio data: %@ %ld %@", [err domain], (long)[err code], [[err userInfo] description]);
    } else {
        NSLog(@"recording saved: %@", recorderFilePath);
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:recorderFilePath];
        [self.commandDelegate sendPluginResult:pluginResult callbackId:_command.callbackId];
    }
}

@end
