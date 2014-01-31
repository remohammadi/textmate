#ifndef COMMITWINDOWCOMMAND_H_8ENSCT9S
#define COMMITWINDOWCOMMAND_H_8ENSCT9S

#import <document/document.h>

void show_command_error (std::string const& message, oak::uuid_t const& uuid, NSWindow* window = nil);
void run_impl (bundle_command_t const& command, ng::buffer_t const& buffer, ng::ranges_t const& selection, document::document_ptr document, std::map<std::string, std::string> baseEnv, std::string const& pwd);

#endif /* end of include guard: COMMITWINDOWCOMMAND_H_8ENSCT9S */


