//
//  AudioRequest.m
//

#import "BTAudioRequest.h"


@implementation BTAudioRequest
@synthesize delegate = _delegate;

static CFTimeInterval kTimeoutInterval = 15;

- (void)dealloc {
  [self cancel];
	[super dealloc];
}

- (id)initRequestWithURL:(NSURL *)url delegate:(id<BTAudioRequestDelegate>)aDelegate {
	self = [super init];
  if (self) {
    self.delegate = aDelegate;
    _request = [[NSMutableURLRequest alloc] initWithURL:url];
    [_request setCachePolicy:NSURLRequestUseProtocolCachePolicy];
    [_request setTimeoutInterval:kTimeoutInterval];
    _connection = [[NSURLConnection alloc] initWithRequest:_request delegate:self startImmediately:NO];
  }
  //[connection scheduleInRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
	return self;
}

- (void)setRequestRange:(NSInteger)start end:(NSInteger)end {
  [_request setValue:[NSString stringWithFormat:@"bytes=%d-%d", start, end] forHTTPHeaderField:@"Range"];
}

- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)aResponse {
	if ([aResponse isKindOfClass:[NSHTTPURLResponse class]]) {
		NSHTTPURLResponse *response = (NSHTTPURLResponse *)aResponse;
		if (response.statusCode == 200) {
       _contentLength = [response expectedContentLength];
      CILog(BTDFLAG_NETWORK,@"_contentLength = %d", _contentLength);
      if (_contentLength > 0) {
        [_delegate audioRequestDidConnectOK:self contentLength:_contentLength];
      } else {
        NSDictionary *userInfo = [NSDictionary dictionaryWithObject:@"HTTP Response Content Length = 0" forKey:NSURLErrorFailingURLStringErrorKey];
        NSError *error = [NSError errorWithDomain:NSURLErrorDomain code:response.statusCode userInfo:userInfo];
        
        [_delegate audioRequest:self didFailWithError:error];
        [self cancel];
      }
      
		} else {
      //CELog(BTDFLAG_NETWORK, @"statusCode = %d", response.statusCode);
      NSDictionary *userInfo = [NSDictionary dictionaryWithObject:[NSString stringWithFormat:@"HTTP Response status code:%d",response.statusCode] forKey:NSURLErrorFailingURLStringErrorKey];
      NSError *error = [NSError errorWithDomain:NSURLErrorDomain code:response.statusCode userInfo:userInfo];
      
			[_delegate audioRequest:self didFailWithError:error];
      [self cancel];
			// prevent the delivery of any more bytes, which would not be audio bytes and
			// therefore could harm the audio subsystems.
    }
	} else { //Not a NSHTTPURLResponse 本地文件路径
    _contentLength = [aResponse expectedContentLength];
    CILog(BTDFLAG_NETWORK,@"_contentLength = %d", _contentLength);
    [_delegate audioRequestDidConnectOK:self contentLength:_contentLength];
  }
}

- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)fromData {
  _dataReceivedLength += [fromData length];
  if (_contentLength > 0) {
    float progress = ((float)_dataReceivedLength/_contentLength);
    CVLog(BTDFLAG_NETWORK,@"progress = %.4f", progress);
    if (progress > 0.998 || progress - _lastProgress > 0.001) {
      _lastProgress = progress;
      [_delegate audioRequest:self downloadProgress:progress];
      
    }
  }
	[_delegate audioRequest:self didReceiveData:fromData];
}

- (void)connection:(NSURLConnection *)aConnection didFailWithError:(NSError *)error {

	[self cancel];
	[_delegate audioRequest:self didFailWithError:error];
  
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection {

	[self cancel];
	[_delegate audioRequestDidFinish:self];
}
- (void)start {
  [_connection start];
  [_delegate audioRequestDidStart:self];
}
- (void)cancel {
  _delegate = nil;
  if (_connection) {
    [_connection cancel];
    //[connection unscheduleFromRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
    [_connection release];
    _connection = nil;
  }
  [_request release];
  _request = nil;
}



/*
 -(NSCachedURLResponse *)connection:(NSURLConnection *)connection
 willCacheResponse:(NSCachedURLResponse *)cachedResponse
 {
 NSCachedURLResponse *newCachedResponse = cachedResponse;
 
 if ([[[[cachedResponse response] URL] scheme] isEqual:@"https"]) {
 newCachedResponse = nil;
 } else {
 NSDictionary *newUserInfo;
 newUserInfo = [NSDictionary dictionaryWithObject:[NSCalendarDate date]
 forKey:@"Cached Date"];
 newCachedResponse = [[[NSCachedURLResponse alloc]
 initWithResponse:[cachedResponse response]
 data:[cachedResponse data]
 userInfo:newUserInfo
 storagePolicy:[cachedResponse storagePolicy]]
 autorelease];
 }
 return newCachedResponse;
 }
 
 */

@end
