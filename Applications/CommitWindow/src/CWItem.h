@interface CWItem : NSObject <NSCopying>
@property (nonatomic, retain) NSString* path;
@property (nonatomic, assign) BOOL state;
@property (nonatomic, assign) NSString* scmStatus;
+ (CWItem*)itemWithPath:(NSString*)aPath andSCMStatus:(NSString*)aStatus;
- (NSComparisonResult)compare:(CWItem*)item;
@end