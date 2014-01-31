#import "CWItem.h"

@implementation CWItem
- (CWItem*)initWithPath:(NSString*)aPath andSCMStatus:(NSString*)aStatus
{
	if((self = [super init]))
	{
		self.path  = aPath;
		self.scmStatus = aStatus;
	}
	return self;
}

+ (CWItem*)itemWithPath:(NSString*)aPath andSCMStatus:(NSString*)aStatus
{
	return [[CWItem alloc] initWithPath:aPath andSCMStatus:aStatus];
}

- (id)copyWithZone:(NSZone*)zone
{
	CWItem* newItem = [[CWItem allocWithZone:zone] initWithPath:_path andSCMStatus:_scmStatus];
	return newItem;
}

- (NSComparisonResult)compare:(CWItem*)item
{
	return [[[self path] lowercaseString] compare:[[item path] lowercaseString]];
}

- (void)setScmStatus:(NSString*)newStatus
{
	if(_scmStatus == newStatus)
		return;
	_scmStatus = newStatus;
	_state = ([newStatus hasPrefix:@"X"] || [newStatus hasPrefix:@"?"]) ? NO : YES;
}

- (void)setNilValueForKey:(NSString*)aKey
{
	if([aKey isEqualToString:@"state"])
	{
		[self setValue:@YES forKey:@"state"];
	}
	else if([aKey isEqualToString:@"path"])
	{
		[self setValue:@"" forKey:@"path"];
	}
	else [super setNilValueForKey:aKey];
}
@end