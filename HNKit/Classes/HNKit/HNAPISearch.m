//
//  HNAPISearch.m
//  newsyc
//
//  Created by Quin Hoxie on 6/2/11.
//

#import "HNAPISearch.h"
#import "HNKit.h"
#import "NSDate+TimeAgo.h"

@class HNEntry;

@interface HNAPISearch () <NSURLConnectionDelegate, NSURLConnectionDataDelegate>
@end

@implementation HNAPISearch

@synthesize entries;
@synthesize responseData;
@synthesize searchType;
@synthesize session;
@synthesize dateFormatter;

- (id)initWithSession:(HNSession *)session_ {
	if (self = [super init]) {
		session = session_;
		[self setSearchType:kHNSearchTypeInteresting];
	}
	
	return self;
}

#pragma mark NSURLConnectionDelegate

- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response {
	[responseData setLength:0];
}

- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data {
	if (responseData == nil) {
		responseData = [[NSMutableData alloc] init];
	}
	
	[responseData appendData:data];
}

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error {
	[connection release];
	[responseData release];
	responseData = nil;
	
	NSNotificationCenter *notificationCenter = [NSNotificationCenter defaultCenter];
	[notificationCenter postNotificationName:@"searchDone" object:nil userInfo:nil];
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection {
	[connection release];

	[self handleResponse];
}

- (void)handleResponse {
	id responseJSON = [NSJSONSerialization JSONObjectWithData:responseData options:0 error:NULL];
	NSArray *rawResults = [[NSArray alloc] initWithArray:[responseJSON objectForKey:@"hits"]];
    
	self.entries = [NSMutableArray array];
    
	for (NSDictionary *result in rawResults) {
		NSDictionary *item = [self itemFromRaw:result];
		HNEntry *entry = [HNEntry session:session entryWithIdentifier:[item objectForKey:@"identifier"]];

		[entry loadFromDictionary:item complete:NO];
		[entries addObject:entry];
	}
	
	[rawResults release];
	rawResults = nil;
	[responseData release];
	responseData = nil;

	NSDictionary *dictToBePassed = [NSDictionary dictionaryWithObject:entries forKey:@"array"];
	NSNotificationCenter *notificationCenter = [NSNotificationCenter defaultCenter];
	[notificationCenter postNotificationName:@"searchDone" object:nil userInfo:dictToBePassed];	
}

- (NSDictionary *)itemFromRaw:(NSDictionary *)rawDictionary {
	NSMutableDictionary *item = [NSMutableDictionary dictionary];
	NSNumber *points = nil;
	NSNumber *comments = nil;
	NSString *title = nil;
	NSString *user = nil;
	NSNumber *identifier = nil;
	NSString *body = nil;
	NSString *date = nil;
	NSString *url = nil;

	points = [rawDictionary valueForKey:@"points"];
	comments = [rawDictionary valueForKey:@"num_comments"];
	title = [rawDictionary valueForKey:@"title"];
	user = [rawDictionary valueForKey:@"author"];
	identifier = [rawDictionary valueForKey:@"objectID"];
	body = [rawDictionary valueForKey:@"comment_text"];
	date = [rawDictionary valueForKey:@"created_at"];
	url = [rawDictionary valueForKey:@"url"];

	if (self.dateFormatter == nil) {
		self.dateFormatter = [[NSDateFormatter alloc] init];
		[dateFormatter setTimeZone:[NSTimeZone timeZoneForSecondsFromGMT:0]];
		[dateFormatter setDateFormat:@"yyyy-MM-dd'T'HH:mm:ss.SSS'Z"];
	}
	NSDate *parsedDate = [dateFormatter dateFromString:date];
	NSString *timeAgo = [parsedDate timeAgoInWords];
    
    if (!timeAgo) {
        timeAgo = @"";
    }
	
	if ((NSNull *)user != [NSNull null]) [item setObject:user forKey:@"user"];
	if ((NSNull *)points != [NSNull null]) [item setObject:points forKey:@"points"];
	if ((NSNull *)title != [NSNull null]) [item setObject:title forKey:@"title"];
	if ((NSNull *)comments != [NSNull null]) [item setObject:comments forKey:@"numchildren"];
	if ((NSNull *)url != [NSNull null]) [item setObject:url forKey:@"url"];
	if ((NSNull *)timeAgo != [NSNull null]) [item setObject:timeAgo forKey:@"date"];
	if ((NSNull *)body != [NSNull null]) [item setObject:body forKey:@"body"];
	if ((NSNull *)identifier != [NSNull null]) [item setObject:identifier forKey:@"identifier"];
	return item;
}

- (void)performSearch:(NSString *)searchQuery {
	NSString *paramsString = nil;
	NSString *encodedQuery = [searchQuery stringByURLEncodingString];
	if (searchType == kHNSearchTypeInteresting) {
		paramsString = [NSString stringWithFormat:kHNSearchParamsInteresting, encodedQuery];
	} else {
		paramsString = [NSString stringWithFormat:kHNSearchParamsRecent, encodedQuery];
	}

	NSString *urlString = [NSString stringWithFormat:kHNSearchBaseURL, paramsString];
	NSURL *url = [NSURL URLWithString:urlString];

	NSURLRequest *request = [[NSURLRequest alloc] initWithURL:url];
	NSURLConnection *connection = [[NSURLConnection alloc] initWithRequest:request delegate:self];
	[connection start];
	[request release];

	searchQuery = nil;
}

- (void)dealloc {
	[responseData release];
	[entries release];
	[dateFormatter release];

	[super dealloc];
}

@end
