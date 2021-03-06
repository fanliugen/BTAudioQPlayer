//
//  AudioPlayer.m
//

#import "BTAudioPlayerInternal.h"
#import <dispatch/dispatch.h>

#define CMD_PLAY @"play"
#define CMD_SEEK @"seek"

@interface BTAudioPlayerInternal (Private)

@property (readwrite) BTAudioPlayerStatus status;

- (void)writeData;
- (void)cancel;
- (void)_playInternal;
- (void)_seekInternal;
@end

@implementation BTAudioPlayerInternal
@synthesize status = _playStatus;
void RunLoopSourcePerformRoutine (void *info);
void RunLoopSourcePlay (void *info);
void RunLoopSourceSeek (void *info);
void RunLoopSourceSeekSchedule(void *info, CFRunLoopRef rl, CFStringRef mode);
void RunLoopSourceSeekCancel(void *info, CFRunLoopRef rl, CFStringRef mode);

void RunLoopSourcePerformRoutine (void *info) {
  if (info != NULL && [(id)info isKindOfClass:[BTAudioPlayerInternal class]]) {
    BTAudioPlayerInternal*  player = (BTAudioPlayerInternal*)info;
    if ([player respondsToSelector:@selector(writeData)]) {
      [player writeData];
    }
  }
}

void RunLoopSourcePlay (void *info) {
  if (info != NULL && [(id)info isKindOfClass:[BTAudioPlayerInternal class]]) {
    BTAudioPlayerInternal*  player = (BTAudioPlayerInternal*)info;
    if ([player respondsToSelector:@selector(_playInternal)]) {
      [player _playInternal];
    }
  }
}

void RunLoopSourceSeekSchedule(void *info, CFRunLoopRef rl, CFStringRef mode) {
  CDLog(BTDFLAG_DEFAULT,@"");
}

void RunLoopSourceSeekCancel(void *info, CFRunLoopRef rl, CFStringRef mode) {
  CDLog(BTDFLAG_DEFAULT,@"");
}
void RunLoopSourceSeek (void *info) {
  if (info != NULL && [(id)info isKindOfClass:[BTAudioPlayerInternal class]]) {
    BTAudioPlayerInternal*  player = (BTAudioPlayerInternal*)info;
    if ([player respondsToSelector:@selector(_seekInternal)]) {
      [player _seekInternal];
    }
  }
}

- (void)dealloc {
	//[self cancel];
  
  _delegate = nil; 
  [_playerItem release];
	[super dealloc];
}

- (id)initPlayerWithDelegate:(id<BTAudioPlayerDelegate>) aDelegate {
	self = [super init];
  if (self) {
    _delegate = aDelegate;
  }
	return self;
}

- (id)initPlayerWithURL:(NSURL *)url delegate:(id<BTAudioPlayerDelegate>) aDelegate {
	self = [super init];
  if (self) {
    _delegate = aDelegate;
    _url = [url retain];
    
  }
	return self;
}

- (void)play:(NSURL*)url {
  CDLog(BTDFLAG_DEFAULT,@"");
  if (url && _url != url) {
    [_url release];
    _url = [url retain];

    [_btRunLoopSource addCommand:CMD_PLAY];
    [_btRunLoopSource fireAllCommands];
    //[self driveRunLoopSourcePlay];
  }
}

- (void)_playInternal {
  NSAssert([[NSThread currentThread].name isEqualToString:@"INTH"],nil);
  CDLog(BTDFLAG_DEFAULT,@"");
  [_audioQueue unbind];
  [_audioQueue release];
  _audioQueue = nil;
  [_playerItem release];
  _playerItem = nil;
  
  _request.delegate = nil;
  [_request cancel];
  [_request release];
  _request = nil;
  
  _fileStream.delegate = nil;
  [_fileStream release];
  _fileStream = nil;
  
  _fileStream = [[BTAudioFileStream alloc] initFileStreamWithDelegate:self];
  [_fileStream open];
  _playerItem = [[BTPlayerItemInternal alloc] initWithURL:_url];
  _request = [[BTAudioRequest alloc] initRequestWithURL:_url delegate:self];
  [_request start];

  self.status = BTAudioPlayerStatusStop;
}


- (void)main {
  CDLog(BTDFLAG_DEFAULT,@"");

  _runLoop = CFRunLoopGetCurrent();
  _btRunLoopSource = [[BTRunLoopSource alloc] init];
  _btRunLoopSource.delegate = self;
  [_btRunLoopSource addToCurrentRunLoop];
  CFRunLoopSourceContext context = {0, self, NULL, NULL, NULL, NULL, NULL, NULL, NULL, &RunLoopSourcePerformRoutine};
  _runLoopSource = CFRunLoopSourceCreate(kCFAllocatorDefault, 0, &context);
  CFRunLoopAddSource(_runLoop, _runLoopSource, kCFRunLoopDefaultMode);

  CFRunLoopSourceContext context1 = {0, self, NULL, NULL, NULL, NULL, NULL, NULL, NULL, &RunLoopSourcePlay};
  _runLoopSourcePlay = CFRunLoopSourceCreate(kCFAllocatorDefault, 0, &context1);
  CFRunLoopAddSource(_runLoop, _runLoopSourcePlay, kCFRunLoopDefaultMode);
  
  CFRunLoopSourceContext context2 = {0, self, NULL, NULL, NULL, NULL, NULL, &RunLoopSourceSeekSchedule, &RunLoopSourceSeekCancel, &RunLoopSourceSeek};
  _runLoopSourceSeek = CFRunLoopSourceCreate(kCFAllocatorDefault, 0, &context2);
  CFRunLoopAddSource(_runLoop, _runLoopSourceSeek, kCFRunLoopDefaultMode);
  
  [_btRunLoopSource addCommand:CMD_PLAY];
  [_btRunLoopSource fireAllCommands];
//  _playerItem = [[BTPlayerItem alloc] initWithURL:_url];
//  _request = [[BTAudioRequest alloc] initRequestWithURL:_url delegate:self];
//  [_request start];
//  //_audioQueue = [[BTAudioQueue alloc] initQueueWithDelegate:self];
//  _fileStream = [[BTAudioFileStream alloc] initFileStreamWithDelegate:self];
//  [_fileStream open];
//  self.status = BTAudioPlayerStatusStop;
  
  heartbeatTimer = [NSTimer scheduledTimerWithTimeInterval:0.25 target:self selector:@selector(writeData) userInfo:nil repeats:YES];
  
  while (_thread && ![_thread isCancelled]) {

    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    @try {
      //CDLog(BTDFLAG_AUDIO_PLAYER, @"Before CFRunLoopRun %d %d",[_thread isCancelled],_thread);
      CFRunLoopRun();
      //CDLog(BTDFLAG_AUDIO_PLAYER, @"AFter CFRunLoopRun %d %d", [_thread isCancelled],_thread);
    }@catch (NSException *exception) {
      
    }@finally {
      
    }
    [pool drain];
  }
  CDLog(BTDFLAG_AUDIO_PLAYER, @"Thread Exit!------");
}

- (void)performCommand:(NSString *)command {
  if ([command isEqualToString:CMD_PLAY]) {
    [self _playInternal];
  } else if([command isEqualToString:CMD_SEEK]) {
    [self _seekInternal];
  }
}

- (void)error {
	[self cancel];
  //TODO: 
	//_delegate performSelectorOnMainThread
}

- (void)seekToTime:(Float64)newSeekTime {
//  [_audioQueue pause];
//  [_audioQueue reset];
//  [_audioQueue pause];
//  self.status = BTAudioPlayerStatusWaiting;
  requestedSeekTime = newSeekTime;
//  [self driveRunLoopSourceSeek];
  [_btRunLoopSource addCommand:CMD_SEEK];
  [_btRunLoopSource fireAllCommands];
}

// internalSeekToTime:
//
// Called from our internal runloop to reopen the stream at a seeked location
//
//- (void) internalSeekToTime:(NSNumber*)newSeekTime {
- (void) _seekInternal {
  NSAssert([[NSThread currentThread].name isEqualToString:@"INTH"],nil);
  CDLog(BTDFLAG_AUDIO_PLAYER, @"_playStatus:%d _audioQueue.status:%d",_playStatus,_audioQueue.status);
  if (_playStatus != BTAudioPlayerStatusPlaying) {
    NSAssert(YES,nil);
    return;
  }
  Float64 nSeekTime = requestedSeekTime;
  if ([_playerItem calculatedBitRate] == 0.0 || _playerItem.expectedContentLength <= 0) {
		return;
	}
  if (nSeekTime > [_playerItem duration]) {
    nSeekTime = [_playerItem duration];
  }
//  [_audioQueue pause];
//  [_audioQueue reset];
  [_audioQueue unbind];
  [_audioQueue release];
  _audioQueue = nil;

  _audioQueue = [[BTAudioQueue alloc] initWithDelegate:self];
  [_audioQueue bind];

  
  self.status = BTAudioPlayerStatusWaiting;
  _playerItem.seekRequested = YES;
  [_playerItem reset];
	//
	// Calculate the byte offset for seeking
	//
	_playerItem.seekByteOffset = _playerItem.dataOffset + (nSeekTime / [_playerItem duration]) * (_playerItem.expectedContentLength - _playerItem.dataOffset);
  
	//
	// Attempt to leave 1 useful packet at the end of the file (although in
	// reality, this may still seek too far if the file has a long trailer).
	//
  
	if (_playerItem.seekByteOffset > [_playerItem.cacheData length] - 20 * _playerItem.packetBufferSize) {
		_playerItem.seekByteOffset =[_playerItem.cacheData length] - 20 * _playerItem.packetBufferSize;
	}
	
	//
	// Store the old time from the audio queue and the time that we're seeking
	// to so that we'll know the correct time progress after seeking.
	//
	_playerItem.seekTime = nSeekTime;
	
	//
	// Attempt to align the seek with a packet boundary
	//
	double calculatedBitRate = [_playerItem calculatedBitRate];
	if (_playerItem.packetDuration > 0 && calculatedBitRate > 0) {
		UInt32 ioFlags = 0;
		SInt64 packetAlignedByteOffset;
		SInt64 seekPacket = floor(nSeekTime / _playerItem.packetDuration);
		//OSStatus err = AudioFileStreamSeek(_streamID, seekPacket, &packetAlignedByteOffset, &ioFlags);
    OSStatus err = [_fileStream seekWithPacketOffset:seekPacket outDataByteOffset:&packetAlignedByteOffset ioFlags:&ioFlags];
		if (!err && !(ioFlags & kAudioFileStreamSeekFlag_OffsetIsEstimated))
		{
			_playerItem.seekTime -= ((_playerItem.seekByteOffset - _playerItem.dataOffset) - packetAlignedByteOffset) * 8.0 / calculatedBitRate;
			_playerItem.seekByteOffset = packetAlignedByteOffset + _playerItem.dataOffset;
		}
	}
  CDLog(BTDFLAG_AUDIO_PLAYER, @"_playerItem.seekByteOffset = %d", _playerItem.seekByteOffset);
  
  
  [self driveRunLoop];
//  [_audioQueue start];
//  self.status = BTAudioPlayerStatusPlaying;
//  [_fileStream close];
//  [_fileStream open];
//  [_audioQueue stop];
//  self.status = BTAudioPlayerStatusStop;
//  if (_request) {
//    [_request cancel];
//    [_request release];
//    _request = nil;
//  }
//  _request = [[BTAudioRequest alloc] initRequestWithURL:_url delegate:self];
//  [_request setRequestRange:_fileStream.seekBtyeOffset end:_fileStream.fileLength - 1];
//  [_request start];
}

#pragma mark -
#pragma mark RunLoop Source
- (void) driveRunLoop {
  return;
  CDLog(BTDFLAG_AUDIO_PLAYER, @" *************** ");
  CFRunLoopSourceSignal(_runLoopSource);
  CFRunLoopWakeUp(_runLoop);
}

- (void) driveRunLoopSourcePlay {
  CDLog(BTDFLAG_AUDIO_PLAYER, @" *************** ");
  CFRunLoopSourceSignal(_runLoopSourcePlay);
  CFRunLoopWakeUp(_runLoop);
}

- (void) driveRunLoopSourceSeek {
  CDLog(BTDFLAG_AUDIO_PLAYER, @" *************** ");
  CFRunLoopSourceSignal(_runLoopSourceSeek);
  CFRunLoopWakeUp(_runLoop);
}
#pragma mark -
#pragma mark BTAudioRequestDelegate
- (void)audioRequestDidStart:(BTAudioRequest *)request {
  NSAssert([[NSThread currentThread].name isEqualToString:@"INTH"],nil);
  self.status = BTAudioPlayerStatusWaiting;
  CILog(BTDFLAG_NETWORK, @"-----------------");
}

- (void)audioRequestDidConnectOK:(BTAudioRequest *)request contentLength:(NSInteger)contentLength {
  NSAssert([[NSThread currentThread].name isEqualToString:@"INTH"],nil);
  CILog(BTDFLAG_NETWORK, @"statusCode = 200");
  self.status = BTAudioPlayerStatusWaiting;
  _playerItem.expectedContentLength = contentLength;
}

- (void)audioRequest:(BTAudioRequest *)request didReceiveData:(NSData *)data {
  NSAssert([[NSThread currentThread].name isEqualToString:@"INTH"],nil);
  //CDLog(BTDFLAG_NETWORK, @"data length = %d", [data length]);
  [_playerItem appendData:data];
  [self driveRunLoop];
  
}

- (void)audioRequest:(BTAudioRequest *)request downloadProgress:(float)progress {
  NSAssert([[NSThread currentThread].name isEqualToString:@"INTH"],nil);
  CVLog(BTDFLAG_NETWORK ,@"progress = %.2f", progress);
  if (_delegate && [_delegate respondsToSelector:@selector(audioPlayer:downloadProgress:)]) {
    dispatch_async(dispatch_get_main_queue(), ^{
      [_delegate audioPlayer:self downloadProgress:progress];
    });
  }
}

- (void)audioRequestDidFinish:(BTAudioRequest *)request {
  NSAssert([[NSThread currentThread].name isEqualToString:@"INTH"],nil);
  CILog(BTDFLAG_NETWORK, @"--player status = %d",_playStatus);
//	if (!audioIsReadyToPlay) {
//		[self error];
//	}
}

- (void)audioRequest:(BTAudioRequest *)request didFailWithError:(NSError*)error {
  NSAssert([[NSThread currentThread].name isEqualToString:@"INTH"],nil);
  CELog(BTDFLAG_NETWORK, @"BTAudioRequest didFailWithError(%i)-%@:%@", error.code,[error localizedDescription],[[error userInfo] objectForKey:NSURLErrorFailingURLStringErrorKey]);
  dispatch_async(dispatch_get_main_queue(), ^{
    //TODO: 错误处理
  });
}
#pragma mark -

- (void)audioFileStream:(BTAudioFileStream *)stream foundMagicCookie:(NSData *)cookie {
  NSAssert([[NSThread currentThread].name isEqualToString:@"INTH"],nil);
	// if an error happens here, it may be recoverable so we let it slide...
	[_audioQueue setMagicCookie:cookie];
}

- (void)audioFileStream:(BTAudioFileStream *)stream isReadyToProducePacketsWithASBD:(AudioStreamBasicDescription)asbd {
  NSAssert([[NSThread currentThread].name isEqualToString:@"INTH"],nil);
  if (_audioQueue == nil) {
    _playerItem.asbd = asbd;
    _playerItem.packetBufferSize = [_fileStream getPacketBufferSize];
    _audioQueue = [[BTAudioQueue alloc] initWithDelegate:self];
    [_audioQueue bind];

    _playerItem.bitRate = [_fileStream getBitRate];
    _playerItem.dataOffset = [_fileStream getDataOffset];
    _playerItem.fileFormat = [_fileStream getFileFormat];
    
	}
}


- (void)audioFileStream:(BTAudioFileStream *)stream callBackWithByteCount:(UInt32)byteCount packetCount:(UInt32)packetCount data:(const void *)inputData packetDescs:(AudioStreamPacketDescription *)packetDescs {
  NSAssert([[NSThread currentThread].name isEqualToString:@"INTH"],nil);
  if (_playerItem.discontinuity) {
    _playerItem.discontinuity = NO;
  }
  if (packetDescs) {
		for (int i = 0; i < packetCount; ++i) {
			UInt64 packetSize = packetDescs[i].mDataByteSize;
      _playerItem.processedPacketsSizeTotal += packetSize;
      _playerItem.processedPacketsCount += 1;
    }
  }
  [_audioQueue fileBufferByteCount:byteCount packetCount:packetCount data:inputData packetDescs:packetDescs];
}

#pragma mark -
#pragma mark AudioQueue Callback

- (BTPlayerItemInternal*)playerItemForAudioQueue:(BTAudioQueue *)audioQueue {
  NSAssert([[NSThread currentThread].name isEqualToString:@"INTH"],nil);
  return _playerItem;
}

//Callback from AQClient thread -> change to Main thread
- (void)audioQueue:(BTAudioQueue *)audioQueue isDoneWithBuffer:(AudioQueueBufferRef)bufferRef {
  //CDLog(BTDFLAG_AUDIO_QUEUE,@">>>");
  [self driveRunLoop];
}

//Callback from AQClient thread -> change to Main thread
- (void)audioQueuePlaybackIsStarting:(BTAudioQueue *)audioQueue {
  CDLog(BTDFLAG_AUDIO_QUEUE, @">>>>>>>>");
  if (self.status == BTAudioPlayerStatusWaiting ||self.status == BTAudioPlayerStatusStop  ) {
//    self.status = BTAudioPlayerStatusPlaying;
//    [_audioQueue start];
    [self performSelector:@selector(startQueue) onThread:_thread withObject:nil waitUntilDone:NO];
  }
}
//Callback from AQClient thread -> change to Main thread
- (void)audioQueuePlaybackIsComplete:(BTAudioQueue *)audioQueue {
  CDLog(BTDFLAG_AUDIO_QUEUE, @"<<<<<<<<<<<-->>>>>>>>>>>>");
  self.status = BTAudioPlayerStatusStop; //TODO: fix bug, bad access when play another music
  [_audioQueue unbind];
//  _audioQueue.delegate = nil;
//	[_audioQueue release];
//  _audioQueue = nil;
}
//Callback from INTH thread
- (void)audioQueueIsFull:(BTAudioQueue *)audioQueue {
  if (self.status == BTAudioPlayerStatusWaiting) {
//    self.status = BTAudioPlayerStatusPlaying;
//    [_audioQueue start];
//    [self performSelector:@selector(startQueue) onThread:_thread withObject:nil waitUntilDone:NO];
    [self startQueue];
  }
}
#pragma mark -
#pragma mark Drive Data

- (void)writeData {
  NSAssert([[NSThread currentThread].name isEqualToString:@"INTH"],nil);
  CDLog(BTDFLAG_AUDIO_PLAYER, @"<<<<bufCountInQueue = %d; _playStatus = %d", _audioQueue.bufCountInQueue, _playStatus);
  if (self.status == BTAudioQueueStatusStopping ||self.status == BTAudioQueueStatusStopped || self.status == BTAudioQueueStatusPaused) {
    return;
  }
  if ([_audioQueue isFull]||[_thread isCancelled]) {
    return;
  }
  NSUInteger availableDataLength = [_playerItem availableDataLength];
  
  //可用数据长度为0了，播放器的状态还在播放
  if (availableDataLength == 0 && (_playStatus == BTAudioPlayerStatusPlaying)) {
    if ([_playerItem isDataComplete]) { //所有数据都下载完了，并且可用数据长度为0，说明数据都已经写到Buffer里了
      if (_audioQueue.status == BTAudioQueueStatusStopping) { // 这里有问题，availableDataLength = 0时， writeData可能不会再进来了
        if ([_audioQueue isEmpty]) {
          [_audioQueue pause];
          [self audioQueuePlaybackIsComplete:_audioQueue];
        }
      } else {
        [_audioQueue endOfStream];
      }
    } else { //还有数据没下载完，Queue需要暂停，播放器表现为等待状态
      [_audioQueue pause];
      self.status = BTAudioPlayerStatusWaiting;
    }
    return;
  } else {
    //TODO: 后续优化解决办法
    //改为kAQDefaultBufSize * 16，暂时解决播放本地文件无法启动播放的问题
    int kAQWriteDataSzie = kAQDefaultBufSize * (16 -_audioQueue.bufCountInQueue);
//    if ([_audioQueue isEmpty]) {
//      kAQWriteDataSzie = kAQDefaultBufSize * 16;
//    }
    if (_playerItem.seekRequested) {
      _playerItem.byteWriteIndex = _playerItem.seekByteOffset;
      _playerItem.seekRequested = NO;
      //[_audioQueue start];
    }

    UInt8 bytes[kAQWriteDataSzie];
    NSUInteger readLength = 0;
    readLength = ((availableDataLength >= kAQWriteDataSzie) ? kAQWriteDataSzie : availableDataLength);
    
    NSData *readData = [NSData dataWithBytes:([_playerItem.cacheData mutableBytes] + _playerItem.byteWriteIndex) length:readLength];
//    uint8_t *readBytes = (uint8_t *)[_playerItem.cacheData mutableBytes];

//    readBytes += _playerItem.byteWriteIndex; // instance variable to move pointer
//    (void)memcpy(bytes, readBytes, readLength);
    
    _playerItem.byteWriteIndex += readLength;
    if (_fileStream) {
      //CDLog(BTDFLAG_AUDIO_PLAYER, @"---_playerItem.discontinuity %d", _playerItem.discontinuity);
//      if (_playerItem.discontinuity) {
//        [_fileStream parseBytes:bytes dataSize:readLength flags:kAudioFileStreamParseFlag_Discontinuity];
//      } else {
//        [_fileStream parseBytes:bytes dataSize:readLength flags:0];
//      }
      if (_playerItem.discontinuity) {
        [_fileStream parseBytes:[readData bytes] dataSize:readLength flags:kAudioFileStreamParseFlag_Discontinuity];
      } else {
        [_fileStream parseBytes:[readData bytes] dataSize:readLength flags:0];
      }
    }
  }
}

#pragma mark -
#pragma mark BTAudioPlayer Control
- (void)start {
  NSAssert([NSThread isMainThread],nil);
  CDLog(BTDFLAG_AUDIO_PLAYER,@">>>>>>>>>>start");
  _thread = [[NSThread alloc] initWithTarget:self selector:@selector(main) object:nil];
  [_thread setName:@"INTH"];
  [_thread start];
}

- (void)stop {
  NSAssert([NSThread isMainThread],nil);
  CDLog(BTDFLAG_AUDIO_PLAYER,@">>>>>>>>>>stop");
  //TODO: waitUntilDone:YES just for test
  [_thread cancel];
  [self performSelector:@selector(cancel) onThread:_thread withObject:nil waitUntilDone:YES];
  [_thread release];
  _thread = nil;
}

- (BOOL)paused {
  NSAssert([NSThread isMainThread],nil);
	return (_playStatus == BTAudioPlayerStatusPaused || _playStatus == BTAudioPlayerStatusStop);
}

- (void)setPaused:(BOOL)paused {
  NSAssert([NSThread isMainThread],nil);
  CDLog(BTDFLAG_AUDIO_PLAYER,@">>>>>>>>>>setPaused:%d",paused);
	if (paused == [self paused]) {
		return;
	}

	if (paused) {
    //[self pauseQueue];
    [self performSelector:@selector(pauseQueue) onThread:_thread withObject:nil waitUntilDone:YES];
	} else {
    //[self startQueue];
    [self performSelector:@selector(startQueue) onThread:_thread withObject:nil waitUntilDone:YES];
	}
}

- (void)startQueue {
  NSAssert([[NSThread currentThread].name isEqualToString:@"INTH"],nil);
  if (self.status == BTAudioPlayerStatusStop) {
//    if (_audioQueue == nil) {
    [_audioQueue bind];
    [_playerItem reset];
    self.status = BTAudioPlayerStatusWaiting;
    [self driveRunLoop];
//    }
  } else {
    [_audioQueue start];
    self.status = BTAudioPlayerStatusPlaying;
  }

//  if ([_audioQueue isEmpty]) {
//    [self driveRunLoop];
//  }
}

- (void)pauseQueue {
  NSAssert([[NSThread currentThread].name isEqualToString:@"INTH"],nil);
  [_audioQueue pause];
  self.status = BTAudioPlayerStatusPaused;
}

- (void)setStatus:(BTAudioPlayerStatus)status {
  NSAssert([[NSThread currentThread].name isEqualToString:@"INTH"],nil);
  if (_playStatus != status) {
//    [self willChangeValueForKey:@"status"];
    _playStatus = status;
//    [self didChangeValueForKey:@"status"];
    if (_delegate) {
      switch (_playStatus) {
        case BTAudioPlayerStatusWaiting:
          dispatch_async(dispatch_get_main_queue(), ^{
            [_delegate audioPlayerWaiting:self];
          });
          break;
        case BTAudioPlayerStatusPlaying:
          dispatch_async(dispatch_get_main_queue(), ^{
            [_delegate audioPlayerStarted:self];
          });
          break;
        case BTAudioPlayerStatusPaused:
          dispatch_async(dispatch_get_main_queue(), ^{
            //TODO: BTAudioPlayerStatusPaused
          });
          break;
        case BTAudioPlayerStatusStop:
          dispatch_async(dispatch_get_main_queue(), ^{
            [_delegate audioPlayerFinished:self];
          });
          break;
        default:
          break;
      }

    }
  }
   //[self setValue:[NSNumber numberWithInt:status] forKey:@"status"];
}

- (void)cancel {
  CDLog(BTDFLAG_AUDIO_PLAYER,@">>>>>>>>>>cancel");
  
  NSAssert([[NSThread currentThread].name isEqualToString:@"INTH"],nil);
  _request.delegate = nil;
  [_request cancel];
	[_request release];
  _request = nil;

  [_audioQueue unbind];

  
  _fileStream.delegate = nil;
	[_fileStream release];
	_fileStream = nil;
  
  [_url release];
  _url = nil;
  
  //CDLog(BTDFLAG_AUDIO_PLAYER, @"_runLoop:%d, _runLoopSource:%d", _runLoop, _runLoopSource);
  if (_runLoop) {
    CFRunLoopRemoveSource(_runLoop, _runLoopSource, kCFRunLoopDefaultMode);
    CFRunLoopRemoveSource(_runLoop, _runLoopSourcePlay, kCFRunLoopDefaultMode);
    CFRelease(_runLoopSource);
    _runLoopSource = NULL;
    CFRelease(_runLoopSourcePlay);
    _runLoopSourcePlay = NULL;
    CFRunLoopStop(_runLoop);
    _runLoop = NULL;
  }


  

  
	// nil out our references so that any further operations
	// (such as cancel during dealloc) don't cause errors.

}

- (Float64)playProgress {
  
  if (_playStatus == BTAudioPlayerStatusPlaying) {
    Float64 progress = 0.0;
    AudioTimeStamp queueTime;
    Boolean discontinuity;
    
    OSStatus status = [_audioQueue getCurrentTime:&queueTime discontinuity:&discontinuity];
    //CDLog(BTDFLAG_AUDIO_PLAYER, @"discontinuity = %d", discontinuity);
    const OSStatus AudioQueueStopped = 0x73746F70; // 0x73746F70 is 'stop'
    if (status == AudioQueueStopped) {
      CVLog(BTDFLAG_AUDIO_PLAYER, @"AudioQueueStopped");
      progress = -2;
    } else if (status) {
      CVLog(BTDFLAG_AUDIO_PLAYER, @"status = %ld", status);
      progress = -3;
    } else {
      progress = _playerItem.seekTime + queueTime.mSampleTime / _playerItem.sampleRate;
      if (progress < 0.0) {
        progress = 0.0;
      }
      _playerItem.playProgress = progress;
    }
  }
  return _playerItem.playProgress;
  //CDLog(BTDFLAG_AUDIO_PLAYER, @"progress = %.3f", progress);
}

- (Float64)duration {
  return [_playerItem duration];
}



#pragma mark -

@end
