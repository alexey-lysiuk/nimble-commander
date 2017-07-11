#include "AlterSymlinkDialog.h"

@interface NCOpsAlterSymlinkDialog ()

@property (strong) IBOutlet NSTextField *Text;
@property (strong) IBOutlet NSTextField *SourcePath;

- (IBAction)OnOk:(id)sender;
- (IBAction)OnCancel:(id)sender;

@end

@implementation NCOpsAlterSymlinkDialog
{
    string m_SrcPath;
    string m_LinkPath;
}

@synthesize sourcePath = m_SrcPath;

- (instancetype)initWithSourcePath:(const string&)_src_path andLinkName:(const string&)_link_name
{
    if( self = [super initWithWindowNibName:@"AlterSymlinkDialog"] ) {
        m_SrcPath = _src_path;
        m_LinkPath = _link_name;
    }
    return self;
}

- (void)windowDidLoad
{
    [super windowDidLoad];
    self.Text.stringValue = [NSString stringWithFormat:@"Symbolic link \'%@\' points at:", [NSString stringWithUTF8StdString:m_LinkPath]];
    self.SourcePath.stringValue = [NSString stringWithUTF8StdString:m_SrcPath];
    [self.window makeFirstResponder:self.SourcePath];
}

- (IBAction)OnOk:(id)sender
{
    m_SrcPath = self.SourcePath.stringValue.fileSystemRepresentationSafe;
    [self.window.sheetParent endSheet:self.window returnCode:NSModalResponseOK];
}

- (IBAction)OnCancel:(id)sender
{
    [self.window.sheetParent endSheet:self.window returnCode:NSModalResponseCancel];
}

@end