#include <TargetConditionals.h>
#if TARGET_OS_IOS
#import <UIKit/UIKit.h>
//
//  FileCache.m
//  Fingerzilla
//
//  Created by Michael Scandizzo on 3/14/13.
//
//

#import "MRFileCache.h"
#import "MRSceneRuntime.h"

#define MAX_THREADS         (2)

@implementation FetchFile

@synthesize strSaveAs = m_strSaveAs;
@synthesize strURL = m_strURL;
@synthesize completionBlock = m_completionBlock;

-(id)init
{
    self = [super init];
    if (self != nil)
    {
        m_strSaveAs = nil;
        m_strURL = nil;
        m_completionBlock = nil;
    }
    return self;
}

- (void)dealloc
{
    NSLog(@"Fetch %x is about to release %x and %x", (int)self, (int)m_strSaveAs, (int)m_strURL);
    (void)0;
    m_strSaveAs = nil;
    (void)0;
    m_strURL = nil;
    (void)0;
    m_completionBlock = nil;
    (void)0;
}

@end

static	MRFileCache		*sFileCache = nil;

@implementation MRFileCache


+(MRFileCache *)sharedFileCache
{
    if (sFileCache == nil)
    {
        sFileCache = [[MRFileCache alloc] init];
    }
    return sFileCache;
}

- (NSString*)getFullPath:(NSString *)strFilename
{
    return [NSString stringWithFormat:@"%@/%@", m_strDirectory, strFilename];
}


-(id)init
{
    self = [super init];
    if (self != nil)
    {
        // Set our directory to /Library/Caches
        NSFileManager *fm = [NSFileManager defaultManager];
        NSArray *paths = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);
        if ([paths count] > 0)
            m_strDirectory = ([paths objectAtIndex:0]);
        else
            m_strDirectory = @"";

        NSError *error = nil;
        NSArray *aContents = [fm contentsOfDirectoryAtPath:m_strDirectory error:&error];
//        NSFileHandle *fpGame = nil;
//        fpGame = [NSFileHandle fileHandleForReadingAtPath:strMapName];

        m_arrFiles = ([[NSMutableArray arrayWithArray:aContents] mutableCopy]);

        m_arrFetchThreads = ([NSMutableArray array]);
        m_arrFetchQueue = ([NSMutableArray array]);
	}
    return self;
}


- (int)getFileSize:(NSString *)strFile
{
    if ([self contains:strFile] == YES)
    {
        NSFileManager *fm = [NSFileManager defaultManager];
        @synchronized(fm)
        {
            NSString *strPath = [self getFullPath:strFile];
            NSError *error = nil;
            NSDictionary *dictAttributes = [fm attributesOfItemAtPath:strPath error:&error];
            if (error != nil)
            {
                NSString *strText = [error localizedDescription];
                NSLog(@"ERROR: %@", strText);
            }
            if (dictAttributes != nil)
            {
                return [dictAttributes fileSize];
            }
        }
    }
    return -1;
}

- (BOOL)contains:(NSString *)strFile
{
    @synchronized(m_arrFiles)
    {
        return [m_arrFiles containsObject:strFile];
    }
}


- (NSDate *)lastModified:(NSString *)strFile
{
    if ([self contains:strFile] == YES)
    {
        NSFileManager *fm = [NSFileManager defaultManager];
        NSString *strPath = [self getFullPath:strFile];
        NSError *error = nil;
        NSDictionary *dictAttributes = [fm attributesOfItemAtPath:strPath error:&error];
        if (dictAttributes != nil)
        {
            return [dictAttributes objectForKey:NSFileModificationDate];
        }
    }
    return nil;
}

- (void)touch:(NSString *)strFile
{
    if ([self contains:strFile] == YES)
    {
        NSFileManager *fm = [NSFileManager defaultManager];
        @synchronized(fm)
        {
            NSString *strPath = [self getFullPath:strFile];
            NSError *error = nil;
            NSMutableDictionary *dictAttributes = [NSMutableDictionary dictionary];
            NSDate *now = [NSDate date];
            [dictAttributes setObject:now forKey:NSFileModificationDate];
            BOOL fSuccess = [fm setAttributes:dictAttributes ofItemAtPath:strPath error:&error];
            if (error != nil)
            {
                NSString *strText = [error localizedDescription];
                NSLog(@"ERROR: %@", strText);
            }
            if (fSuccess == YES)
            {
                NSLog(@"Touched %@.", strPath);
            }
        }
    }
}

- (void)addFile:(NSString *)strFilename data:(NSData *)data
{
    NSString *strPath = [self getFullPath:strFilename];

    NSFileManager *fm = [NSFileManager defaultManager];

    if ([self contains:strFilename] == YES)
    {
        NSError *error = nil;
        [fm removeItemAtPath:strPath error:&error];
    }

    // Create the file
    BOOL fCreated = [fm createFileAtPath:strPath contents:data attributes:nil];

    // Or overwrite it
    if (fCreated != NO)
    {
        NSFileHandle *file = [NSFileHandle fileHandleForWritingAtPath:strPath];
        [file writeData:data];
        [file closeFile];
    }

    @synchronized(m_arrFiles)
    {
        [m_arrFiles addObject:strFilename];
    }

}

- (void)removeFile:(NSString*)strFilename
{
    NSString *strPath = [self getFullPath:strFilename];

    if ([self contains:strFilename] == NO)
        return;

    // Remove the actual file.
    NSFileManager *fm = [NSFileManager defaultManager];
    NSError *error = nil;
    [fm removeItemAtPath:strPath error:&error];

    // Remove our reference.
    @synchronized(m_arrFiles)
    {
        [m_arrFiles removeObject:strFilename];
    }
}

- (NSData *)getFile:(NSString *)strFilename
{
    NSFileHandle *fhFile = [self getFileHandle:strFilename];
    if (fhFile == nil)
        return nil;

    return [fhFile readDataToEndOfFile];
}

- (NSFileHandle*)getFileHandle:(NSString *)strFilename
{
    if ([self contains:strFilename] == NO)
        return nil;

    NSString *strPath = [self getFullPath:strFilename];
    NSFileHandle *file = [NSFileHandle fileHandleForReadingAtPath:strPath];
    return file;
}

- (void)fetchFileFromURL:(NSString *)strURL
{
    // Just use the existing filename.
    NSArray *arrComponents = [strURL componentsSeparatedByString:@"/"];
    if ([arrComponents count] < 1)
    {
        NSLog(@"Couldn't find default file name to fetch %@!", strURL);
        return;
    }

    NSString *strSaveAs = [arrComponents lastObject];
    [self fetchFileFromURL:strURL saveAs:strSaveAs withCompletion:nil];
}

- (void)fetchFileFromURL:(NSString *)strURL saveAs:(NSString *)strSaveAs
{
    [self fetchFileFromURL:strURL saveAs:strSaveAs withCompletion:nil];
}

- (void)fetchFileFromURL:(NSString *)strURL saveAs:(NSString *)strSaveAs loadAsTexture:(BOOL)fLoadTexture
{
    [self fetchFileFromURL:strURL saveAs:strSaveAs withCompletion:^(NSString *strFilename, EFileChangeStatus eStatus)
     {
         [self loadTexture:strFilename];
     }];
}

- (void)fetchFileFromURL:(NSString *)strURL saveAs:(NSString *)strSaveAs withCompletion:(void(^)(NSString *strFilename, EFileChangeStatus eStatus))block
{
    if (strURL == nil)
        return;

    FetchFile *fetchData = [[FetchFile alloc] init];
    fetchData.strSaveAs = strSaveAs;
    fetchData.strURL = strURL;
    fetchData.completionBlock = block;
    @synchronized(m_arrFetchQueue)
    {
        [m_arrFetchQueue addObject:fetchData];
    }

    int nThreadCount = 0;
    @synchronized(m_arrFetchThreads)
    {
        NSArray *arrThreadsCopy = [NSArray arrayWithArray:m_arrFetchThreads];
        for(NSThread *thread in arrThreadsCopy)
        {
            if ([thread isFinished] == YES)
            {
                [m_arrFetchThreads removeObject:thread];
            }
        }
        nThreadCount = [m_arrFetchThreads count];
    }

    if (nThreadCount >= MAX_THREADS)
        return;

    NSThread *threadFetch = [[NSThread alloc] initWithTarget:self selector:@selector(threadRun) object:nil];
    [threadFetch setThreadPriority:0.25f];  // Lower our thread priority.
    [threadFetch start];
    @synchronized(m_arrFetchThreads)
    {
        [m_arrFetchThreads addObject:threadFetch];
    }
}

// Internal operations

- (void)threadRun
{
    FetchFile *fetch = [self getNextFetch];
    while (fetch != nil)
    {
        NSString *strSaveName = nil;
        NSString *strSaveAs = [NSString stringWithString:fetch.strSaveAs];
        NSString *strURL = [NSString stringWithString:fetch.strURL];
        NSArray *arrURLParts = [strURL componentsSeparatedByString:@"/"];
        NSString *strURLName = [arrURLParts lastObject];
        void     (^completionBlock)(NSString *strFilename, EFileChangeStatus eStatus) = [fetch.completionBlock copy];

        NSLog(@"threadRun on [%x] with [%@] and [%@].", (int)fetch, strSaveAs, strURL);
        if (strSaveAs != nil)
            strSaveName = strSaveAs;
        else
            strSaveName = strURLName;
        (fetch);
        fetch = nil;

        NSURL *urlDownload = [NSURL URLWithString:strURL];

        NSURLRequest *reqDownload = [NSURLRequest requestWithURL:urlDownload
                                                     cachePolicy:NSURLRequestUseProtocolCachePolicy
                                                 timeoutInterval:15.0];

        EFileChangeStatus eStatus = FCS_NO_CHANGE;
        NSURLResponse *response = nil;
        NSError *error = nil;
        NSData *data = [NSURLConnection sendSynchronousRequest:reqDownload returningResponse:&response error:&error];
        if (error == nil)
        {
            if ([self contains:strSaveName] == YES)
            {
                NSLog(@"File already in cache: %@", strSaveName);
                int nExistingSize = [self getFileSize:strSaveName];
                int nNewSize = [response expectedContentLength];
                if (nExistingSize == nNewSize)
                {
                    if (completionBlock != nil)
                    {
                        completionBlock(strSaveAs, FCS_NO_CHANGE);
                    }
                    fetch = [self getNextFetch];
                    continue;
                }
                else
                {
                    NSLog(@"File cache sizes don't match.  Downloading %@.", strSaveName);
                    eStatus = FCS_CHANGED_FILE;
                }
            }
            else
            {
                eStatus = FCS_NEW_FILE;
            }

            NSLog(@"Downloaded: %@ from %@", strSaveName, strURL);
            [self addFile:strSaveName data:data];
            if (completionBlock != nil)
            {
                completionBlock(strSaveAs, eStatus);
            }
        }
        else
        {
            NSLog(@"FileCache fetch failed for: %@.", [error localizedDescription]);
            // Some errors we will retry, others we won't...
            int nCode = [error code];
            if (nCode == NSURLErrorUnsupportedURL)
            {
                // Don't  do anything...
                NSLog(@"  Code %d: Cancelling request.", nCode);
            }
            else
            {
                // Otherwise, let's retry.
                NSLog(@"  Code %d: Requeing request.", nCode);
                [self fetchFileFromURL:strURL saveAs:strSaveAs];
            }
        }
        fetch = [self getNextFetch];
    }
}

// Must do the texture loading operation in the main thread.
- (void)loadTexture:(NSString *)strSaveName
{
    [self performSelectorOnMainThread:@selector(helperLoadTexture:) withObject:strSaveName waitUntilDone:YES];
}

- (void)helperLoadTexture:(NSString *)strSaveName
{
    NSData *data = [self getFile:strSaveName];
    UIImage *imageNew = [UIImage imageWithData:data];

    // Sanity -- might still not get the actual file.
    if (imageNew == nil)
    {
        NSLog(@"ERROR: helperLoadTeture -- failed to get image data for [%@].", strSaveName);
        return;
    }

    // For some reason, we need to convert to PNG (from JPG or ?) here, or we get
    // weird alpha issues on older phones/iOS versions.
    imageNew = [UIImage imageWithData:UIImagePNGRepresentation(imageNew)];
    [[MRSceneRuntime sharedRuntime] cacheImage:imageNew named:strSaveName];
}

- (FetchFile *)getNextFetch
{
    FetchFile *fetch = nil;
    @synchronized(m_arrFetchQueue)
    {
        if ([m_arrFetchQueue count] > 0)
        {
            fetch = [m_arrFetchQueue objectAtIndex:0];
            [m_arrFetchQueue removeObject:fetch];
        }
    }
    return fetch;
}

@end

#endif
