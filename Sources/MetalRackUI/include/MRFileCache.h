//
//  FileCache.h
//  Fingerzilla
//
//  Created by Michael Scandizzo on 3/14/13.
//
//

#import <Foundation/Foundation.h>

typedef enum
{
    FCS_NO_CHANGE = 0,
    FCS_NEW_FILE,
    FCS_CHANGED_FILE,

    // Keep this last.
    FCS_NUM_TYPES
} EFileChangeStatus;

@interface FetchFile : NSObject
{
    NSString		*m_strSaveAs;
    NSString		*m_strURL;
    void            (^m_completionBlock)(NSString *strFilename, EFileChangeStatus eStatus);
}

@property (nonatomic, copy) NSString   *strSaveAs;
@property (nonatomic, copy) NSString   *strURL;
@property (nonatomic, copy) void       (^completionBlock)(NSString *strFilename, EFileChangeStatus eStatus);

-(id)init;

@end


@interface MRFileCache : NSObject <NSURLConnectionDataDelegate>
{
    NSString                *m_strDirectory;
    NSMutableArray          *m_arrFiles;
    NSMutableArray          *m_arrFetchThreads; // = new ArrayList<Thread>();
    NSMutableArray          *m_arrFetchQueue;  // new ArrayList<FetchFile>();
}

+(MRFileCache *)sharedFileCache;

- (int)getFileSize:(NSString *)strFile;
- (BOOL)contains:(NSString *)strFile;
- (NSString*)getFullPath:(NSString *)strFilename;
- (NSDate *)lastModified:(NSString *)strFile;
- (void)touch:(NSString *)strFile;
- (void)addFile:(NSString *)strFilename data:(NSData *)data;
- (void)removeFile:(NSString*)strFilename;
- (NSData *)getFile:(NSString *)strFilename;
- (NSFileHandle*)getFileHandle:(NSString *)strFilename;
- (void)fetchFileFromURL:(NSString *)strURL;
- (void)fetchFileFromURL:(NSString *)strURL saveAs:(NSString *)strSaveAs;
- (void)fetchFileFromURL:(NSString *)strURL saveAs:(NSString *)strSaveAs loadAsTexture:(BOOL)fLoadTexture;
- (void)fetchFileFromURL:(NSString *)strURL saveAs:(NSString *)strSaveAs withCompletion:(void(^)(NSString *strFilename, EFileChangeStatus eStatus))block;
- (void)loadTexture:(NSString *)strSaveName;

@end
