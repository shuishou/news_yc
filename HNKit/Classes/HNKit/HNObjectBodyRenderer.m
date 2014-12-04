//
//  HNObjectBodyRenderer.m
//  newsyc
//
//  Created by Grant Paul on 2/26/12.
//  Copyright (c) 2012 Xuzz Productions, LLC. All rights reserved.
//

#import "HNShared.h"

#ifdef HNKIT_RENDERING_ENABLED

#import "HNObjectBodyRenderer.h"

#import "HNObject.h"
#import "HNEntry.h"
#import "HNUser.h"

#import "XMLDocument.h"
#import "XMLElement.h"

#ifndef IS_MAC_OS_X
#import <UIKit/UIKit.h>
#else
#import <Cocoa/Cocoa.h>
#endif

static const CGFloat HNObjectBodyRendererLinkColor[3] = {9.0 / 255.0, 33 / 255.0, 234 / 255.0};

static CGFloat defaultFontSize = 13.0f;

@implementation HNObjectBodyRenderer
@synthesize object;

+ (CGFloat)defaultFontSize {
    return defaultFontSize;
}

+ (void)setDefaultFontSize:(CGFloat)size {
    defaultFontSize = size;
}

#ifndef IS_MAC_OS_X
- (CTFontRef)fontForFont:(UIFont *)font {
#else
- (CTFontRef)fontForFont:(NSFont *)font {
#endif
    static NSCache *fontCache = nil;
    if (fontCache == nil) fontCache = [[NSCache alloc] init];
    
    // This is okay as we only setup the font based on the name and size anyway.
    NSArray *key = [NSArray arrayWithObjects:[font fontName], [NSNumber numberWithFloat:[font pointSize]], nil];
    
    if ([fontCache objectForKey:font]) {
        return (CTFontRef) [fontCache objectForKey:key];
    } else {
        CTFontRef ref = CTFontCreateWithName((CFStringRef) [font fontName], [font pointSize], NULL);
        [fontCache setObject:(id) ref forKey:key];
        return ref;
    }
}

#ifndef IS_MAC_OS_X
- (UIColor *)colorFromHexString:(NSString *)hex {
#else
- (NSColor *)colorFromHexString:(NSString *)hex {
#endif
    if ([hex hasPrefix:@"#"]) hex = [hex substringFromIndex:1];
    
    NSScanner *scanner = [NSScanner scannerWithString:hex];
    [scanner setCharactersToBeSkipped:[NSCharacterSet symbolCharacterSet]]; 
    
    NSUInteger color;
    [scanner scanHexInt:&color]; 
    
    CGFloat red   = ((color & 0xFF0000) >> 16) / 255.0f;
    CGFloat green = ((color & 0x00FF00) >>  8) / 255.0f;
    CGFloat blue  = ((color & 0x0000FF) >>  0) / 255.0f;

#ifndef IS_MAC_OS_X
    return [UIColor colorWithRed:red green:green blue:blue alpha:1.0f];
#else
    return [NSColor colorWithCalibratedRed:red green:green blue:blue alpha:1.0f];
#endif
}

- (NSString *)text {
    if ([object isKindOfClass:[HNEntry class]]) {
        HNEntry *entry = (HNEntry *) object;
        return [entry body];
    } else if ([object isKindOfClass:[HNUser class]]) {
        HNUser *user = (HNUser *) object;
        NSString *body = [user about];

        body = [body stringByReplacingOccurrencesOfString:@"<p>" withString:@"\n\n"];

        __block NSInteger lastIndex = 0;
        NSMutableString *markupBody = [NSMutableString string];

        NSDataDetector *dataDetector = [NSDataDetector dataDetectorWithTypes:(NSTextCheckingTypes)NSTextCheckingTypeLink error:NULL];
        [dataDetector enumerateMatchesInString:body options:0 range:NSMakeRange(0, [body length]) usingBlock:^(NSTextCheckingResult *result, NSMatchingFlags flags, BOOL *stop) {
            NSRange range = [result range];
            NSURL *url = [result URL];

            if ([[url scheme] isEqualToString:@"mailto"]) {
                // XXX: support mailto: URLs
                url = nil;
            }

            [markupBody appendString:[body substringWithRange:NSMakeRange(lastIndex, range.location - lastIndex)]];
            
            if (url != nil) {
                NSString *addressString = [url absoluteString];
                [markupBody appendString:[NSString stringWithFormat:@"<a href=\"%@\">", addressString]];
            }
            
            [markupBody appendString:[body substringWithRange:range]];
            
            if (url != nil) {
                [markupBody appendString:@"</a>"];
            }

            lastIndex = range.location + range.length;
        }];

        [markupBody appendString:[body substringFromIndex:lastIndex]];

        [markupBody replaceOccurrencesOfString:@"\n" withString:@"<br />" options:0 range:NSMakeRange(0, [markupBody length])];
        
        return markupBody;
    }

    return nil;
}

- (NSAttributedString *)createAttributedString {
    NSString *body = [self text];
    if ([body length] == 0) return [[[NSAttributedString alloc] init] autorelease];
    
    CGFloat fontSize = [[self class] defaultFontSize];
    
#ifndef IS_MAC_OS_X
    CTFontRef fontBody = [self fontForFont:[UIFont systemFontOfSize:fontSize]];
    CTFontRef fontCode = [self fontForFont:[UIFont fontWithName:@"Courier New" size:fontSize]];
    CTFontRef fontItalic = [self fontForFont:[UIFont italicSystemFontOfSize:fontSize]];
    CTFontRef fontSmallParagraphBreak = [self fontForFont:[UIFont systemFontOfSize:floorf(fontSize * 2.0f / 3.0f)]];
    
    CGColorRef colorBody = [[UIColor blackColor] CGColor];
    CGColorRef colorLink = [[UIColor colorWithRed:HNObjectBodyRendererLinkColor[0] green:HNObjectBodyRendererLinkColor[1] blue:HNObjectBodyRendererLinkColor[2] alpha:1.0] CGColor];
#else
    CTFontRef fontBody = [self fontForFont:[NSFont systemFontOfSize:fontSize]];
    CTFontRef fontCode = [self fontForFont:[NSFont fontWithName:@"Courier New" size:fontSize]];
    CTFontRef fontItalic = [self fontForFont:[NSFont italicSystemFontOfSize:fontSize]];
    CTFontRef fontSmallParagraphBreak = [self fontForFont:[NSFont systemFontOfSize:floorf(fontSize * 2.0f / 3.0f)]];
    
    CGColorRef colorBody = [[NSColor blackColor] CGColor];
    CGColorRef colorLink = [[NSColor colorWithCalibratedRed:HNObjectBodyRendererLinkColor[0] green:HNObjectBodyRendererLinkColor[1] blue:HNObjectBodyRendererLinkColor[2] alpha:1.0] CGColor];
#endif
    
    __block NSMutableAttributedString *bodyAttributed = [[NSMutableAttributedString alloc] init];
    __block NSMutableDictionary *currentAttributes = [NSMutableDictionary dictionary];
    
    BOOL(^hasContent)() = ^BOOL {
        return [[[bodyAttributed string] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] length] != 0;
    };
        
    void(^formatBody)(NSMutableDictionary *, XMLElement *) = ^(NSMutableDictionary *attributes, XMLElement *element) {
        [attributes setObject:(id) colorBody forKey:(NSString *) kCTForegroundColorAttributeName];
        [attributes setObject:(id) fontBody forKey:(NSString *) kCTFontAttributeName];
    };
    
    void(^formatFont)(NSMutableDictionary *, XMLElement *) = ^(NSMutableDictionary *attributes, XMLElement *element) {
        NSString *colorText = [element attributeWithName:@"color"];
        CGColorRef color = [[self colorFromHexString:colorText] CGColor];
        
        [attributes setObject:(id) color forKey:(NSString *) kCTForegroundColorAttributeName];
    };
    
    void(^formatCode)(NSMutableDictionary *, XMLElement *) = ^(NSMutableDictionary *attributes, XMLElement *element) {
        [attributes setObject:(id) fontCode forKey:(NSString *) kCTFontAttributeName];
        [attributes setObject:(id) kCFBooleanTrue forKey:@"PreserveWhitepace"];
    };
    
    void(^formatItalic)(NSMutableDictionary *, XMLElement *) = ^(NSMutableDictionary *attributes, XMLElement *element) {
        [attributes setObject:(id) fontItalic forKey:(NSString *) kCTFontAttributeName];
    };
    
    void(^formatLink)(NSMutableDictionary *, XMLElement *) = ^(NSMutableDictionary *attributes, XMLElement *element) {
        NSString *href = [element attributeWithName:@"href"];
        
        [attributes setObject:(id) colorLink forKey:(NSString *) kCTForegroundColorAttributeName];
        if (href != nil) [attributes setObject:href forKey:@"LinkDestination"];
        [attributes setObject:[NSNumber numberWithInt:arc4random()] forKey:@"LinkIdentifier"];
    };

    void(^formatParagraph)(NSMutableDictionary *, XMLElement *) = ^(NSMutableDictionary *attributes, XMLElement *element) {
        if (!hasContent()) return;
        
        NSAttributedString *newlineString = [[NSAttributedString alloc] initWithString:@"\n" attributes:attributes];
        [bodyAttributed appendAttributedString:[newlineString autorelease]];
        
        NSMutableDictionary *blankLineAttributes = [[attributes mutableCopy] autorelease];
        [blankLineAttributes setObject:(id) fontSmallParagraphBreak forKey:(NSString *) kCTFontAttributeName];
        NSAttributedString *blankLineString = [[NSAttributedString alloc] initWithString:@"\n" attributes:blankLineAttributes];
        [bodyAttributed appendAttributedString:[blankLineString autorelease]];
    };
    
    void (^formatNewline)(NSMutableDictionary *, XMLElement *) = ^(NSMutableDictionary *attributes, XMLElement *element) {
        if (!hasContent()) return;
        
        NSAttributedString *childString = [[NSAttributedString alloc] initWithString:@"\n" attributes:nil];
        [bodyAttributed appendAttributedString:[childString autorelease]];
    };
    
    NSDictionary *tagActions = [NSDictionary dictionaryWithObjectsAndKeys:
        [[formatParagraph copy] autorelease], @"p",
        [[formatCode copy] autorelease], @"pre",
        [[formatItalic copy] autorelease], @"i",
        [[formatLink copy] autorelease], @"a",
        [[formatFont copy] autorelease], @"font",
        [[formatNewline copy] autorelease], @"br",
        [[formatBody copy] autorelease], @"body",
    nil];

    __block void(^formatChildren)(XMLElement *) = ^(XMLElement *element) {
        for (XMLElement *child in [element children]) {
            if (![child isTextNode]) {
                NSMutableDictionary *savedAttributes = [[currentAttributes mutableCopy] autorelease];
                
                NSAttributedString *(^formatAction)(NSMutableDictionary *, XMLElement *element) = [tagActions objectForKey:[child tagName]];
                if (formatAction != NULL) formatAction(currentAttributes, child);
                
                formatChildren(child);
                
                currentAttributes = savedAttributes;
            } else {
                NSString *content = [child content];
                
                // strip out whitespace not in <pre> when 
                if (![[currentAttributes objectForKey:@"PreserveWhitepace"] boolValue]) {
                    while ([content rangeOfString:@"  "].location != NSNotFound) {
                        content = [content stringByReplacingOccurrencesOfString:@"  " withString:@" "];
                    }
                    
                    content = [content stringByReplacingOccurrencesOfString:@"\n" withString:@""];
                } else {
                    NSString *prefix = @"  ";
                    
                    if ([content hasPrefix:prefix]) {
                        content = [content substringFromIndex:[prefix length]];
                    }
                    
                    content = [content stringByReplacingOccurrencesOfString:[@"\n" stringByAppendingString:prefix] withString:@"\n"];
                    
                    if (hasContent()) {
                        content = [content stringByAppendingString:@"\n"];
                    }
                }
                
                NSAttributedString *childString = [[NSAttributedString alloc] initWithString:content attributes:currentAttributes];
                [bodyAttributed appendAttributedString:[childString autorelease]];
            }
        }
    };
    
    // ensure body has a root element
    body = [NSString stringWithFormat:@"<body>%@</body>", body];
    
    XMLDocument *xml = [[XMLDocument alloc] initWithHTMLData:[body dataUsingEncoding:NSUTF8StringEncoding]];
    formatChildren([xml firstElementMatchingPath:@"/"]);
    [xml release];
    
    /*CFRelease(fontBody);
    CFRelease(fontCode);
    CFRelease(fontItalic);*/
    
    return [bodyAttributed autorelease];
}

- (CGSize)sizeForWidth:(CGFloat)width {
    CGSize size = CGSizeZero;
    size.width = width;
    size.height = CGFLOAT_MAX;
    
    size = CTFramesetterSuggestFrameSizeWithConstraints(framesetter, CFRangeMake(0, [attributed length]), NULL, size, NULL);
    return size;
}

- (NSURL *)linkURLAtPoint:(CGPoint)point forWidth:(CGFloat)width rects:(NSSet **)rects {
    CGSize size = [self sizeForWidth:width];
    CGRect rect = CGRectMake(0, 0, size.width, size.height);
    
    // flip it into CoreText coordinates
    point.y = size.height - point.y;
    
    CGMutablePathRef path = CGPathCreateMutable();
    CGPathAddRect(path, NULL, rect);
    
    CTFrameRef frame = CTFramesetterCreateFrame(framesetter, CFRangeMake(0, 0), path, NULL);    
    NSArray *lines = (NSArray *) CTFrameGetLines(frame);
    
    CGPoint *origins = (CGPoint *) calloc(sizeof(CGPoint), [lines count]);
    CTFrameGetLineOrigins(frame, CFRangeMake(0, 0), origins);
    
    CGRect (^computeLineRect)(CTLineRef, NSInteger) = ^CGRect (CTLineRef line, NSInteger index) {
        CGRect lineRect;
        lineRect.origin.x = 0;
        lineRect.origin.y = origins[index].y;
        
        CGFloat ascent, descent, leading;
        lineRect.size.width = CTLineGetTypographicBounds(line, &ascent, &descent, &leading);
        lineRect.size.height = ascent + descent;
        
        return lineRect;
    };
    
    CGRect (^computeRunRect)(CTRunRef, CTLineRef, CGRect) = ^CGRect (CTRunRef run, CTLineRef line, CGRect lineRect) {                    
        CGRect runRect;
        CGFloat ascent, descent;
        runRect.size.width = CTRunGetTypographicBounds(run, CFRangeMake(0, 0), &ascent, &descent, NULL);
        runRect.size.height = ascent + descent;
        runRect.origin.x = lineRect.origin.x + CTLineGetOffsetForStringIndex(line, CTRunGetStringRange(run).location, NULL);
        runRect.origin.y = lineRect.origin.y - descent;
        
        return runRect;
    };
    
    for (NSInteger i = 0; i < [lines count]; i++) {
        CTLineRef line = (CTLineRef) [lines objectAtIndex:i];
        CGRect lineBounds = computeLineRect(line, i);
        
        CGFloat ascent, descent, leading;
        CTLineGetTypographicBounds(line, &ascent, &descent, &leading);
                
        // if the bottom of the line is less than the point
        if (lineBounds.origin.y - descent < point.y) {
            NSArray *runs = (NSArray *) CTLineGetGlyphRuns(line);
                        
            for (NSInteger j = 0; j < [runs count]; j++) {
                CTRunRef run = (CTRunRef) [runs objectAtIndex:j];
                CGRect runBounds = computeRunRect(run, line, lineBounds);
                
                if (runBounds.origin.x + runBounds.size.width > point.x) {
                    NSDictionary *attributes = (NSDictionary *) CTRunGetAttributes(run);
                    NSURL *url = [NSURL URLWithString:[attributes objectForKey:@"LinkDestination"]];
                    NSNumber *linkIdentifier = [attributes objectForKey:@"LinkIdentifier"];
                    
                    if (linkIdentifier != nil && rects != NULL) {
                        NSMutableSet *runRects = [NSMutableSet set];
                        
                        for (NSInteger k = 0; k < [lines count]; k++) {
                            CTLineRef line = (CTLineRef) [lines objectAtIndex:k];
                            NSArray *runs = (NSArray *) CTLineGetGlyphRuns(line);

                            for (NSInteger l = 0; l < [runs count]; l++) {
                                CTRunRef run = (CTRunRef) [runs objectAtIndex:l];
                                NSDictionary *attributes = (NSDictionary *) CTRunGetAttributes(run);

                                NSNumber *runIdentifier = [attributes objectForKey:@"LinkIdentifier"];
                                if ([runIdentifier isEqual:linkIdentifier]) {
                                    CGRect lineRect = computeLineRect(line, k);
                                    CGRect runRect = computeRunRect(run, line, lineRect);
                                    
                                    // flip it back into the top-left coordinate system
                                    runRect.origin.y = size.height - (runRect.origin.y + runRect.size.height);
                                    
                                    NSValue *rectValue = [NSValue valueWithCGRect:runRect];
                                    [runRects addObject:rectValue];
                                }
                            }
                        }
                        
                        *rects = (NSSet *) runRects;
                    }
                    
                    free(origins);
                    CFRelease(frame);
                    CFRelease(path);
                    return url;
                }
            }
            
            free(origins);
            CFRelease(frame);
            CFRelease(path);
            return nil;
        }
    }
    
    free(origins);
    CFRelease(frame);
    CFRelease(path);
    return nil;
}

- (void)renderInContext:(CGContextRef)context rect:(CGRect)rect {
    CGContextSaveGState(context);
    
    CGContextSetTextMatrix(context, CGAffineTransformIdentity);
    CGContextTranslateCTM(context, rect.origin.x, rect.origin.y);
    CGContextScaleCTM(context, 1.0f, -1.0f);
    CGContextTranslateCTM(context, -rect.origin.x, -(rect.origin.y + rect.size.height));
    
    CGMutablePathRef path = CGPathCreateMutable();
    CGPathAddRect(path, NULL, rect);
    
    CTFrameRef frame = CTFramesetterCreateFrame(framesetter, CFRangeMake(0, 0), path, NULL);    
    CTFrameDraw(frame, context);
    
    CGPathRelease(path);  
    CFRelease(frame);
    
    CGContextRestoreGState(context);  
}

- (void)prepare {
    if (framesetter != NULL) CFRelease(framesetter);
    [attributed release];
    
    attributed = [[self createAttributedString] retain];
    framesetter = CTFramesetterCreateWithAttributedString((CFAttributedStringRef) attributed);
}

- (NSString *)string {
    return [attributed string];
}

- (NSString *)HTMLString {
    return [[[self text] copy] autorelease];
}

- (NSAttributedString *)attributedString {
    return [[attributed copy] autorelease];
}

- (id)initWithObject:(HNObject *)object_ {
    if ((self = [super init])) {
        object = object_;
        [self prepare];
        
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(prepare) name:kHNObjectLoadingStateChangedNotification object:object];
    }
    
    return self;
}

- (void)dealloc {
    CFRelease(framesetter);
    [attributed release];
    
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    
    [super dealloc];
}

@end

#endif
