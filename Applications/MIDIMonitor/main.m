#import <Cocoa/Cocoa.h>
#import <OmniBase/OmniBase.h>

int main(int argc, const char *argv[])
{
    [OBPostLoader processClasses];
    return NSApplicationMain(argc, argv);
}
