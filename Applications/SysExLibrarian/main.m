#import <Cocoa/Cocoa.h>

int main(int argc, const char *argv[])
{
    // Register defaults early
    NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init]; 
	NSString* defaultDefaultsPath = [[NSBundle mainBundle] pathForResource:@"Defaults" ofType:@"plist"];
	if (defaultDefaultsPath && [defaultDefaultsPath length] > 0) {
		NSDictionary* defaultDefaults = [NSDictionary dictionaryWithContentsOfFile: defaultDefaultsPath];
		if (defaultDefaults) {
			[[NSUserDefaults standardUserDefaults] registerDefaults:defaultDefaults];			
		}
	}
    [pool release];
    
    return NSApplicationMain(argc, argv);
}
