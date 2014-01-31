#import "CommitWindowCommand.h"
#import "CommitWindow.h"
#import <OakFoundation/NSString Additions.h>
#import <OakSystem/application.h>
#import <OakSystem/process.h>
#import <OakAppKit/OakAppKit.h>
#import <command/runner.h>
#import <ns/ns.h>
#import <oak/oak.h>
#import <bundles/bundles.h>
#import <document/collection.h>
#import <editor/editor.h>
#import <editor/write.h>
#import <io/path.h>
#import <text/trim.h>
#import <text/tokenize.h>

namespace
{
	struct commit_window_delegate_t : command::delegate_t
	{
		commit_window_delegate_t (CommitWindow* controller, document::document_ptr document) : _controller(controller),  _document(document) { }

		ng::range_t write_unit_to_fd (int fd, input::type unit, input::type fallbackUnit, input_format::type format, scope::selector_t const& scopeSelector, std::map<std::string, std::string>& variables, bool* inputWasSelection);

		bool accept_html_data (command::runner_ptr runner, char const* data, size_t len);
		bool accept_result (std::string const& out, output::type placement, output_format::type format, output_caret::type outputCaret, ng::range_t inputRange, std::map<std::string, std::string> const& environment);
		void discard_html ();

		void show_tool_tip (std::string const& str);
		void show_document (std::string const& str);
		void show_error (bundle_command_t const& command, int rc, std::string const& out, std::string const& err);

	private:
		CommitWindow* _controller;
		document::document_ptr _document;
	};
}

ng::range_t commit_window_delegate_t::write_unit_to_fd (int fd, input::type unit, input::type fallbackUnit, input_format::type format, scope::selector_t const& scopeSelector, std::map<std::string, std::string>& variables, bool* inputWasSelection)
{
	if(!_document)
	{
		close(fd);
		return ng::range_t();
	}

	bool isOpen = _document->is_open();
	if(!isOpen)
		_document->open();
	ng::range_t res = ng::write_unit_to_fd(_document->buffer(), ng::editor_for_document(_document)->ranges().last(), _document->buffer().indent().tab_size(), fd, unit, fallbackUnit, format, scopeSelector, variables, inputWasSelection);
	if(!isOpen)
		_document->close();
	return res;
}

bool commit_window_delegate_t::accept_html_data (command::runner_ptr runner, char const* data, size_t len)
{
	return false;
}

void commit_window_delegate_t::discard_html ()
{

}

bool commit_window_delegate_t::accept_result (std::string const& out, output::type placement, output_format::type format, output_caret::type outputCaret, ng::range_t inputRange, std::map<std::string, std::string> const& environment)
{
	bool res;
	if(_document && _document->is_open())
	{
		res = ng::editor_for_document(_document)->handle_result(out, placement, format, outputCaret, inputRange, environment);
	}
	else
	{
		document::document_ptr doc = document::create();
		doc->open();
		res = ng::editor_for_document(doc)->handle_result(out, placement, format, outputCaret, ng::range_t(0), environment);
		document::show(doc);
		doc->close();
	}
	return res;
}

// ========================================
// = Showing tool tip, document, or error =
// ========================================

void commit_window_delegate_t::show_tool_tip (std::string const& str)
{

}

void commit_window_delegate_t::show_document (std::string const& str)
{

}

void commit_window_delegate_t::show_error (bundle_command_t const& command, int rc, std::string const& out, std::string const& err)
{
	show_command_error(text::trim(err + out).empty() ? text::format("Command returned status code %d.", rc) : err + out, command.uuid, _controller.window);
}

void show_command_error (std::string const& message, oak::uuid_t const& uuid, NSWindow* window)
{
}

void run_impl (bundle_command_t const& command, ng::buffer_t const& buffer, ng::ranges_t const& selection, document::document_ptr document, std::map<std::string, std::string> baseEnv, std::string const& pwd)
{
	// FIXME: Since we are a separate process no need to reliably track which controller sent the command. This might change in the future.
	NSWindow* window = [NSApp keyWindow];
	CommitWindow* controller = (CommitWindow*)window.delegate;
	command::runner_ptr runner = command::runner(command, buffer, selection, baseEnv, std::make_shared<commit_window_delegate_t>(controller, document), pwd);
	runner->launch();
	runner->wait();

}