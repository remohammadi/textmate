//  Created by Chris Thomas on 2/6/05.
//  Copyright 2005-2007 Chris Thomas. All rights reserved.
//	MIT license.
//
#import "CommitWindow.h"
#import "CommitWindowCommand.h"
#import "CWItem.h"
#import "CWStatusStringTransformer.h"
#import "NSTask+CXAdditions.h"
#import <OakFoundation/NSString Additions.h>
#import <document/collection.h>
#import <settings/settings.h>
#import <bundles/bundles.h>

@interface actionCommandObj : NSObject
@property (nonatomic, readonly) NSString* name;
@property (nonatomic, readonly) NSSet* targetStatuses;
@property (nonatomic, readonly) NSArray* command;
+ (actionCommandObj*)actionCommandWithString:(NSString*)aString;
@end

@implementation actionCommandObj
- (id)initWithName:(NSString*)aName command:(NSArray*)aCommand andTargetStatuses:(NSSet*)theTargetStatuses
{
	if((self = [super init]))
	{
		_name = aName;
		_command = aCommand;
		_targetStatuses = theTargetStatuses;
	}
	return self;
}

+ (actionCommandObj*)actionCommandWithString:(NSString*)aString
{
	NSRange range = [aString rangeOfString:@":"];
	NSArray* commandComponents = [[aString substringFromIndex:NSMaxRange(range)] componentsSeparatedByString:@","];
	NSString* statuses = [aString substringToIndex:range.location];
	NSArray* command = [commandComponents subarrayWithRange:NSMakeRange(1, [commandComponents count] - 1)];
	return [[actionCommandObj alloc] initWithName:[commandComponents objectAtIndex:0] command:command andTargetStatuses:[NSSet setWithArray:[statuses componentsSeparatedByString:@","]]];
}
@end

@implementation CommitWindow

- (void)awakeFromNib
{
	[self parseArguments];

	[CWStatusStringTransformer register];
	[self populateTableView];

	if(char const* appPath = getenv("TM_APP_PATH"))
		settings_t::set_default_settings_path(path::join(appPath, "Contents/Resources/Default.tmProperties"));

	settings_t::set_global_settings_path(path::join(path::home(), "Library/Application Support/TextMate/Global.tmProperties"));

	// Load bundle index
	std::vector<std::string> paths;
	for(auto path : bundles::locations())
		paths.push_back(path::join(path, "Bundles"));

	plist::cache_t cache;
	cache.load_capnp(path::join(path::home(), "Library/Caches/com.macromates.TextMate/BundlesIndex.binary"));

	auto index = create_bundle_index(paths, cache);
	bundles::set_index(index.first, index.second);

	documentView.textView.delegate = self;
	documentView.textView.font = [NSFont userFixedPitchFontOfSize:12];
	commitMessage = document::document_ptr();

	std::string file_type = "text.plain";

	std::string scm_name = getenv("TM_SCM_NAME");
	std::string file_grammar = "text." + scm_name + "-commit";
	for(auto item : bundles::query(bundles::kFieldGrammarScope, file_grammar, scope::wildcard, bundles::kItemTypeGrammar))
	{
		if(item)
			file_type = item->value_for_field(bundles::kFieldGrammarScope);
	}

	if(NSString* logMessage = [self.options objectForKey:@"--log"])
		commitMessage = document::from_content([logMessage UTF8String], file_type);
	else commitMessage = document::from_content("", file_type);
	[documentView setDocument:commitMessage];

	settings_t const settings = settings_for_path();
	std::string themeUUID = settings.get(kSettingsThemeKey, NULL_STR);
	if(themeUUID != NULL_STR)
		[documentView setThemeWithUUID:[NSString stringWithCxxString:themeUUID]];

	{
		ProcessSerialNumber process;

		GetCurrentProcess(&process);
		SetFrontProcess(&process);
	}

	[[self window] setLevel:NSModalPanelWindowLevel];
	[[self window] center];
}

- (void)parseArguments
{
	NSArray* optionKeys = @[@"--ask", @"--log", @"--diff-cmd", @"--action-cmd", @"--status"];
	NSArray* args = [[NSProcessInfo processInfo] arguments];
	args = [args subarrayWithRange:NSMakeRange(1, [args count]-1)];

	self.options = [NSMutableDictionary dictionary];
	self.parameters = [NSMutableArray array];

	NSEnumerator* enumerator = [args objectEnumerator];
	NSString* arg;

	NSMutableArray* actions = [NSMutableArray array];

	if([args count] < 2)
		[self cancelCommit:nil];

	while (arg = [enumerator nextObject])
	{
		if([optionKeys containsObject:arg])
		{
			if(NSString* value = [enumerator nextObject])
			{
				if([arg isEqualToString:@"--action-cmd"])
					[actions addObject:[actionCommandObj actionCommandWithString:value]];
				else [self.options addEntriesFromDictionary:@{arg : value}];
			}
			else [self cancelCommit:nil];
		}
		else [self.parameters addObject:arg];
	}

	if(actions != nil | [actions count] != 0)
		[self.options setObject:actions forKey:@"--action-cmd"];
}

- (void)populateTableView
{
	NSArray* statuses = [[self.options objectForKey:@"--status"] componentsSeparatedByString:@":"];
	for(NSUInteger i = 0; i < [statuses count]; i++)
	{
		NSString* status = [statuses objectAtIndex:i];
		CWItem* item = [CWItem itemWithPath:[self.parameters objectAtIndex:i] andSCMStatus:status];
		[arrayController addObject:item];
	}

}
- (void)dealloc
{
}

- (NSString*)absolutePathForPath:(NSString*)path
{
	if([path hasPrefix:@"/"])
		return path;

	NSString* absolutePath = nil;
	NSString* errorText;
	int exitStatus;
	NSArray* arguments = [NSArray arrayWithObjects:@"/usr/bin/which", path, nil];

	exitStatus = [NSTask executeTaskWithArguments:arguments input:nil outputString:&absolutePath errorString:&errorText];
	[self checkExitStatus:exitStatus forCommand:arguments errorText:errorText];

	// Trim whitespace
	absolutePath = [absolutePath stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];

	return absolutePath;
}

- (void)checkExitStatus:(int)exitStatus forCommand:(NSArray*)arguments errorText:(NSString*)errorText
{
	if( exitStatus != 0 )
	{
		// This error dialog text sucks for an isolated end user, but allows us to diagnose the problem accurately.
		NSRunAlertPanel(errorText, @"Exit status (%d) while executing %@", @"OK", nil, nil, exitStatus, arguments);
		[NSException raise:@"ProcessFailed" format:@"Subprocess %@ unsuccessful.", arguments];
	}
}

- (IBAction)commit:(id)sender
{
   fprintf(stdout, " -m '%s' ", documentView.document->content().c_str());
	for(CWItem* item in [arrayController arrangedObjects])
	{
		if(item.state)
		{
			NSMutableString* path = [[item.path stringByStandardizingPath] mutableCopy];
			[path replaceOccurrencesOfString:@"'" withString:@"'\"'\"'" options:0 range:NSMakeRange(0, [path length])];
			fprintf(stdout, "'%s' ", [path UTF8String]);
		}
	}
	fprintf(stdout, "\n");
	[NSApp terminate:self];
}

- (IBAction)cancelCommit:(id)sender
{
	[[self window] close];
	fprintf(stdout, "commit window: cancel\n");
	exit(-128);
}

// ===================
// = Action Commands =
// ===================

- (IBAction)showDiff:(id)sender
{
	NSMutableArray* arguments = [[[self.options objectForKey:@"--diff-cmd"] componentsSeparatedByString:@","] mutableCopy];
	NSData* diffData;
	NSString* errorText;
	int exitStatus;
	NSString* filePath = [[[[arrayController arrangedObjects] objectAtIndex:[tableView selectedRow]] path] stringByStandardizingPath];

	[arguments replaceObjectAtIndex:0 withObject:[self absolutePathForPath:[arguments objectAtIndex:0]]];

	// Run the diff
	[arguments addObject:filePath];
	exitStatus = [NSTask executeTaskWithArguments:arguments input:nil outputData:&diffData errorString:&errorText];
	[self checkExitStatus:exitStatus forCommand:arguments errorText:errorText];

	// Success, send the diff to TextMate
	arguments = [NSArray arrayWithObjects:[NSString stringWithFormat:@"%s/bin/mate", getenv("TM_SUPPORT_PATH")], @"-a", nil];
	exitStatus = [NSTask executeTaskWithArguments:arguments input:diffData outputData:nil errorString:&errorText];
	[self checkExitStatus:exitStatus forCommand:arguments errorText:errorText];
}

- (IBAction)performActionCommand:(id)sender
{
	actionCommandObj* cmd = [sender representedObject];
	NSMutableArray* arguments = [cmd.command mutableCopy];
	NSString* filePath        = [[[[arrayController arrangedObjects] objectAtIndex:[tableView selectedRow]] path] stringByStandardizingPath];

	NSString* pathToCommand;
	NSString* errorText;
	NSString* outputStatus;
	int exitStatus;
	// make sure we have an absolute path
	pathToCommand = [self absolutePathForPath:[arguments objectAtIndex:0]];
	[arguments replaceObjectAtIndex:0 withObject:pathToCommand];

	[arguments addObject:filePath];

	exitStatus = [NSTask executeTaskWithArguments:arguments input:nil outputString:&outputStatus errorString:&errorText];
	[self checkExitStatus:exitStatus forCommand:arguments errorText:errorText];

	//
	// Set the file status to the new status
	//
	NSRange rangeOfStatus;
	NSString* newStatus;

	rangeOfStatus = [outputStatus rangeOfCharacterFromSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
	if(rangeOfStatus.location == NSNotFound)
	{
		NSRunAlertPanel(@"Cannot understand output from command", @"Command %@ returned '%@'", @"OK", nil, nil, arguments, outputStatus);
		[NSException raise:@"CannotUnderstandReturnValue" format:@"Don't understand %@", outputStatus];
	}

	newStatus = [outputStatus substringToIndex:rangeOfStatus.location];

	[[arrayController arrangedObjects] setScmStatus:newStatus];
}

- (IBAction)checkAll:(id)sender
{
	for(CWItem* item in [arrayController arrangedObjects])
	{
		if(!item.state)
			item.state = YES;
	}
}

- (IBAction)uncheckAll:(id)sender
{
	for(CWItem* item in [arrayController arrangedObjects])
	{
		if(item.state)
			item.state = NO;
	}
}


// ========================
// = OakTextView Delegate =
// ========================

- (std::map<std::string, std::string>)variables
{
	std::map<std::string, std::string> res;
	res["TM_PROJECT_DIRECTORY"] = getenv("TM_PROJECT_DIRECTORY");
	return res;
}

// ========================
// = NSTableView Delegate =
// ========================

- (void)tableView:(NSTableView*)aTableView willDisplayCell:(id)aCell forTableColumn:(NSTableColumn*)aColumn row:(NSInteger)rowIndex
{
	if([[aColumn identifier] isEqualToString:@"FILES_COLUMN"])
	{
		NSMenu* actionMenu = [NSMenu new];
		actionMenu.delegate = self;
		[actionMenu setAutoenablesItems:NO];

		if([self.options objectForKey:@"--diff-cmd"])
		{
			[actionMenu addItemWithTitle:@"Show Diff" action:@selector(showDiff:) keyEquivalent:@""];
			[actionMenu addItem:[NSMenuItem separatorItem]];
		}

		CWItem* commitWindowItem = [[arrayController arrangedObjects] objectAtIndex:rowIndex];

		if(NSArray* commands = [self.options objectForKey:@"--action-cmd"])
		{
			for(actionCommandObj* cmd in commands)
			{
				NSMenuItem* item = [actionMenu addItemWithTitle:cmd.name action:@selector(performActionCommand:) keyEquivalent:@""];
				[item setRepresentedObject:cmd];

				if([cmd.targetStatuses containsObject:commitWindowItem.scmStatus])
					[item setEnabled:YES];
				else [item setEnabled: NO];

			}
			[actionMenu addItem:[NSMenuItem separatorItem]];
		}

		[actionMenu addItemWithTitle:@"Check All" action:@selector(checkAll:) keyEquivalent:@""];
		[actionMenu addItemWithTitle:@"Uncheck All" action:@selector(uncheckAll:) keyEquivalent:@""];
		[aCell setMenu:actionMenu];
	}
}

+ (void)load
{
	// set document proxy
	static struct proxy_t : document::ui_proxy_t
	{
	public:
		void show_browser (std::string const& path) const
		{
		}

		void show_documents (std::vector<document::document_ptr> const& documents) const
		{
		}

		void show_document (oak::uuid_t const& collection, document::document_ptr document, text::range_t const& range, bool bringToFront) const
		{
		}

		void run (bundle_command_t const& command, ng::buffer_t const& buffer, ng::ranges_t const& selection, document::document_ptr document, std::map<std::string, std::string> const& env, std::string const& pwd)
		{
			run_impl(command, buffer, selection, document, env, pwd);
		}

	} proxy;

	document::set_ui_proxy(&proxy);
}
@end
