[
    {
      command = "workbench.action.terminal.focus";
      key = "ctrl+[Equal]";
    }
    {
      command = "workbench.action.focusActiveEditorGroup";
      key = "ctrl+[";
    }
    {
      command = "-workbench.action.files.newUntitledFile";
      key = "ctrl+n";
    }
    {
      command = "workbench.action.openGlobalKeybindings";
      key = "ctrl+\\";
    }
    {
      command = "workbench.action.openGlobalKeybindings";
      key = "ctrl+[IntlYen]";
    }
    {
      command = "-workbench.action.openGlobalKeybindings";
      key = "ctrl+k ctrl+s";
    }
    {
      command = "editor.unfold";
      key = "ctrl+x p";
      when = "editorTextFocus && foldingEnabled";
    }
    {
      command = "-editor.unfold";
      key = "ctrl+shift+]";
      when = "editorTextFocus && foldingEnabled";
    }
    {
      command = "editor.fold";
      key = "ctrl+x i";
      when = "editorTextFocus && foldingEnabled";
    }
    {
      command = "-editor.fold";
      key = "ctrl+shift+[";
      when = "editorTextFocus && foldingEnabled";
    }
    {
      command = "-workbench.action.newWindow";
      key = "ctrl+x ctrl+n";
      when = "!terminalFocus";
    }
    {
      command = "-workbench.action.zoomIn";
      key = "ctrl+=";
    }
    {
      command = "-workbench.action.zoomOut";
      key = "ctrl+-";
    }
    {
      command = "-editor.action.outdentLines";
      key = "ctrl+[";
      when = "editorTextFocus && !editorReadonly";
    }
    {
      command = "workbench.action.closeActiveEditor";
      key = "ctrl+x 0";
    }
    {
      command = "-workbench.action.closeActiveEditor";
      key = "ctrl+w";
    }
    {
      command = "-workbench.action.lastEditorInGroup";
      key = "ctrl+9";
    }
    {
      command = "deleteWordPartRight";
      key = "ctrl+9";
    }
    {
      command = "deleteWordPartLeft";
      key = "ctrl+0";
    }
    {
      command = "-deleteWordRight";
      key = "ctrl+delete";
      when = "textInputFocus && !editorReadonly";
    }
    {
      command = "-deleteWordLeft";
      key = "ctrl+backspace";
      when = "textInputFocus && !editorReadonly";
    }
    {
      command = "workbench.action.quickOpen";
      key = "ctrl+x b";
    }
    {
      command = "-workbench.action.quickOpen";
      key = "ctrl+p";
    }
    {
      command = "-workbench.action.nextEditor";
      key = "ctrl+pagedown";
    }
    {
      command = "list.focusDown";
      key = "ctrl+n";
      when = "listFocus && !inputFocus";
    }
    {
      command = "-list.focusDown";
      key = "down";
      when = "listFocus && !inputFocus";
    }
    {
      command = "-cursorUp";
      key = "up";
      when = "textInputFocus";
    }
    {
      command = "list.focusUp";
      key = "ctrl+p";
      when = "listFocus && !inputFocus";
    }
    {
      command = "-list.focusUp";
      key = "up";
      when = "listFocus && !inputFocus";
    }
    {
      command = "-selectPrevSuggestion";
      key = "up";
      when = "suggestWidgetMultipleSuggestions && suggestWidgetVisible && textInputFocus";
    }
    {
      command = "-showPrevParameterHint";
      key = "up";
      when = "editorFocus && parameterHintsMultipleSignatures && parameterHintsVisible";
    }
    {
      command = "-showPrevParameterHint";
      key = "up";
      when = "parameterHintsMultipleSignatures && parameterHintsVisible && textInputFocus";
    }
    {
      command = "-workbench.banner.focusNextAction";
      key = "down";
      when = "bannerFocused";
    }
    {
      command = "-workbench.action.interactivePlayground.arrowDown";
      key = "down";
      when = "interactivePlaygroundFocus && !editorTextFocus";
    }
    {
      command = "-emacs-mcx.isearchExit";
      key = "down";
      when = "editorFocus && findWidgetVisible && !config.emacs-mcx.cursorMoveOnFindWidget && !isComposing && !replaceInputFocussed";
    }
    {
      command = "-workbench.statusBar.focusNext";
      key = "down";
      when = "statusBarFocused";
    }
    {
      command = "-selectPrevSuggestion";
      key = "ctrl+up";
      when = "suggestWidgetMultipleSuggestions && suggestWidgetVisible && textInputFocus";
    }
    {
      command = "-selectPrevCodeAction";
      key = "up";
      when = "codeActionMenuVisible";
    }
    {
      command = "-workbench.action.toggleSidebarVisibility";
      key = "ctrl+b";
    }
    {
      command = "explorer.openToSide";
      key = "ctrl+x ctrl+d";
      when = "explorerViewletFocus && explorerViewletVisible && !inputFocus";
    }
    {
      command = "-explorer.openToSide";
      key = "ctrl+enter";
      when = "explorerViewletFocus && explorerViewletVisible && !inputFocus";
    }
    {
      command = "-workbench.action.showAllEditorsByMostRecentlyUsed";
      key = "ctrl+x b";
      when = "!terminalFocus";
    }
    {
      command = "-workbench.action.files.save";
      key = "ctrl+s";
    }
    {
      command = "-workbench.action.terminal.focusFind";
      key = "ctrl+f";
      when = "terminalFindFocused && terminalHasBeenCreated || terminalFindFocused && terminalProcessSupported || terminalFocus && terminalHasBeenCreated || terminalFocus && terminalProcessSupported";
    }
    {
      command = "-settings.action.search";
      key = "ctrl+f";
      when = "inSettingsEditor";
    }
    {
      command = "actions.find";
      key = "ctrl+s";
      when = "(editorFocus || editorIsOpen) && !findInputFocussed";
    }
    {
      command = "-actions.find";
      key = "ctrl+f";
      when = "editorFocus || editorIsOpen";
    }
    {
      command = "keybindings.editor.searchKeybindings";
      key = "ctrl+s";
      when = "inKeybindings";
    }
    {
      command = "-keybindings.editor.searchKeybindings";
      key = "ctrl+f";
      when = "inKeybindings";
    }
    {
      command = "list.find";
      key = "ctrl+s";
      when = "listFocus && listSupportsFind";
    }
    {
      command = "-list.find";
      key = "ctrl+f";
      when = "listFocus && listSupportsFind";
    }
    {
      command = "list.expand";
      key = "ctrl+f";
      when = "listFocus && treeElementCanExpand && !inputFocus || listFocus && treeElementHasChild && !inputFocus";
    }
    {
      command = "-list.expand";
      key = "right";
      when = "listFocus && treeElementCanExpand && !inputFocus || listFocus && treeElementHasChild && !inputFocus";
    }
    {
      command = "list.collapse";
      key = "ctrl+b";
      when = "listFocus && treeElementCanCollapse && !inputFocus || listFocus && treeElementHasParent && !inputFocus";
    }
    {
      command = "-list.collapse";
      key = "left";
      when = "listFocus && treeElementCanCollapse && !inputFocus || listFocus && treeElementHasParent && !inputFocus";
    }
    {
      command = "-workbench.action.togglePanel";
      key = "ctrl+j";
    }
    {
      command = "-workbench.action.togglePanel";
      key = "ctrl+x j";
      when = "!terminalFocus";
    }
    {
      command = "-editor.action.triggerSuggest";
      key = "ctrl+space";
      when = "editorHasCompletionItemProvider && textInputFocus && !editorReadonly";
    }
    {
      command = "emacs-mcx.cancel";
      key = "ctrl+space";
      when = "emacs-mcx.inMarkMode";
    }
    {
      command = "-editor.action.startFindReplaceAction";
      key = "ctrl+h";
      when = "editorFocus || editorIsOpen";
    }
    {
      command = "workbench.files.action.createFolderFromExplorer";
      key = "ctrl+u ctrl+f";
    }
    {
      command = "emacs-mcx.cancel";
      key = "ctrl+g";
    }
    {
      command = "-emacs-mcx.cancel";
      key = "ctrl+g";
      when = "editorTextFocus";
    }
    {
      command = "interactive.input.clear";
      key = "ctrl+g";
      when = "!LinkedEditingInputVisible && !accessibilityHelpWidgetVisible && !breakpointWidgetVisible && !editorHasMultipleSelections && !editorHasSelection && !editorHoverVisible && !exceptionWidgetVisible && !findWidgetVisible && !inSnippetMode && !isComposing && !markersNavigationVisible && !notificationToastsVisible && !parameterHintsVisible && !renameInputVisible && !selectionAnchorSet && !suggestWidgetVisible && resourceScheme == 'vscode-interactive'";
    }
    {
      command = "-cursorUndo";
      key = "ctrl+u";
      when = "textInputFocus";
    }
    {
      command = "workbench.files.action.createFolderFromExplorer";
      key = "ctrl+u f";
    }
    {
      command = "-workbench.action.quickOpen";
      key = "ctrl+e";
    }
    {
      command = "explorer.openToSide";
      key = "ctrl+x d";
      when = "explorerViewletFocus && explorerViewletVisible && !inputFocus";
    }
    {
      command = "-workbench.action.quickOpenNavigateNextInFilePicker";
      key = "ctrl+p";
      when = "inFilesPicker && inQuickOpen";
    }
    {
      command = "leaveEditorMessage";
      key = "ctrl+g";
      when = "messageVisible";
    }
    {
      command = "leaveSnippet";
      key = "ctrl+g";
      when = "editorTextFocus && inSnippetMode";
    }
    {
      command = "cancelLinkedEditingInput";
      key = "ctrl+g";
      when = "LinkedEditingInputVisible && editorTextFocus";
    }
    {
      command = "cancelRenameInput";
      key = "ctrl+g";
      when = "editorFocus && renameInputVisible";
    }
    {
      command = "cancelSelection";
      key = "ctrl+g";
      when = "editorHasSelection && textInputFocus";
    }
    {
      command = "closeAccessibilityHelp";
      key = "ctrl+g";
      when = "accessibilityHelpWidgetVisible && editorFocus";
    }
    {
      command = "closeReferenceSearch";
      key = "escape";
      when = "inReferenceSearchEditor";
    }
    {
      command = "closeReferenceSearch";
      key = "ctrl+g";
      when = "referenceSearchVisible";
    }
    {
      command = "closeReplaceInFilesWidget";
      key = "ctrl+g";
      when = "replaceInputBoxFocus && searchViewletVisible";
    }
    {
      command = "commentsClearFilterText";
      key = "ctrl+g";
      when = "commentsFilterFocus";
    }
    {
      command = "editor.action.inlineSuggest.hide";
      key = "ctrl+g";
      when = "inlineSuggestionVisible";
    }
    {
      command = "editor.action.webvieweditor.hideFind";
      key = "ctrl+g";
      when = "webviewFindWidgetVisible && !editorFocus && activeEditor == 'WebviewEditor'";
    }
    {
      command = "editor.cancelOperation";
      key = "ctrl+g";
      when = "cancellableOperation";
    }
    {
      command = "editor.closeCallHierarchy";
      key = "ctrl+g";
      when = "callHierarchyVisible && !config.editor.stablePeek";
    }
    {
      command = "hideCodeActionWidget";
      key = "ctrl+g";
      when = "codeActionMenuVisible";
    }
    {
      command = "hideSuggestWidget";
      key = "ctrl+g";
      when = "suggestWidgetVisible && textInputFocus";
    }
    {
      command = "interactive.input.clear";
      key = "ctrl+g";
      when = "!LinkedEditingInputVisible && !accessibilityHelpWidgetVisible && !breakpointWidgetVisible && !editorHasMultipleSelections && !editorHasSelection && !editorHoverVisible && !exceptionWidgetVisible && !findWidgetVisible && !inSnippetMode && !isComposing && !markersNavigationVisible && !notificationToastsVisible && !parameterHintsVisible && !renameInputVisible && !selectionAnchorSet && !suggestWidgetVisible && resourceScheme == 'vscode-interactive'";
    }
    {
      command = "keybindings.editor.clearSearchResults";
      key = "ctrl+g";
      when = "inKeybindings && inKeybindingsSearch";
    }
    {
      command = "workbench.action.closeQuickOpen";
      key = "ctrl+g";
      when = "inQuickOpen";
    }
    {
      command = "workbench.action.hideComment";
      key = "ctrl+g";
      when = "commentEditorFocused";
    }
    {
      command = "workbench.banner.focusBanner";
      key = "ctrl+g";
      when = "bannerFocused";
    }
    {
      command = "workbench.statusBar.clearFocus";
      key = "ctrl+g";
      when = "statusBarFocused";
    }
    {
      command = "settings.action.focusLevelUp";
      key = "ctrl+g";
      when = "inSettingsEditor && !inSettingsJSONEditor && !inSettingsSearch";
    }
    {
      command = "workbench.action.hideInterfaceOverview";
      key = "ctrl+g";
      when = "interfaceOverviewVisible";
    }
    {
      command = "welcome.goBack";
      key = "ctrl+g";
      when = "inWelcome && activeEditor == 'gettingStartedPage'";
    }
    {
      command = "renameFile";
      key = "ctrl+u ctrl+r";
      when = "explorerViewletVisible && filesExplorerFocus && !explorerResourceIsRoot && !explorerResourceReadonly && !inputFocus";
    }
    {
      command = "-renameFile";
      key = "f2";
      when = "explorerViewletVisible && filesExplorerFocus && !explorerResourceIsRoot && !explorerResourceReadonly && !inputFocus";
    }
    {
      command = "renameFile";
      key = "ctrl+u r";
      when = "explorerViewletVisible && filesExplorerFocus && !explorerResourceIsRoot && !explorerResourceReadonly && !inputFocus";
    }
    {
      command = "filesExplorer.copy";
      key = "alt+w";
      when = "explorerViewletVisible && filesExplorerFocus && !explorerResourceIsRoot && !inputFocus";
    }
    {
      command = "-filesExplorer.copy";
      key = "ctrl+c";
      when = "explorerViewletVisible && filesExplorerFocus && !explorerResourceIsRoot && !inputFocus";
    }
    {
      command = "filesExplorer.cut";
      key = "ctrl+w";
      when = "explorerViewletVisible && filesExplorerFocus && !explorerResourceIsRoot && !explorerResourceReadonly && !inputFocus";
    }
    {
      command = "-filesExplorer.cut";
      key = "ctrl+x";
      when = "explorerViewletVisible && filesExplorerFocus && !explorerResourceIsRoot && !explorerResourceReadonly && !inputFocus";
    }
    {
      command = "filesExplorer.paste";
      key = "ctrl+y";
      when = "explorerViewletVisible && filesExplorerFocus && !explorerResourceReadonly && !inputFocus";
    }
    {
      command = "-filesExplorer.paste";
      key = "ctrl+v";
      when = "explorerViewletVisible && filesExplorerFocus && !explorerResourceReadonly && !inputFocus";
    }
    {
      command = "explorer.newFile";
      key = "ctrl+x ctrl+n";
      when = "explorerViewletFocus";
    }
    {
      command = "explorer.newFile";
      key = "ctrl+u ctrl+i";
    }
    {
      command = "-workbench.action.openEditorAtIndex2";
      key = "alt+2";
    }
    {
      command = "editor.action.rename";
      key = "ctrl+x ctrl+r";
      when = "editorHasRenameProvider && editorTextFocus && !editorReadonly";
    }
    {
      command = "-editor.action.rename";
      key = "f2";
      when = "editorHasRenameProvider && editorTextFocus && !editorReadonly";
    }
    {
      command = "editor.action.rename";
      key = "ctrl+x r";
      when = "editorHasRenameProvider && editorTextFocus && !editorReadonly";
    }
    {
      command = "-editor.debug.action.toggleBreakpoint";
      key = "f9";
      when = "debuggersAvailable && editorTextFocus";
    }
    {
      command = "workbench.action.debug.continue";
      key = "f9";
      when = "debugState == 'stopped'";
    }
    {
      command = "-workbench.action.debug.continue";
      key = "f5";
      when = "debugState == 'stopped'";
    }
    {
      command = "workbench.action.debug.stepOver";
      key = "f8";
      when = "debugState == 'stopped'";
    }
    {
      command = "-workbench.action.debug.stepOver";
      key = "f10";
      when = "debugState == 'stopped'";
    }
    {
      command = "workbench.action.debug.stepInto";
      key = "f7";
      when = "debugState != 'inactive'";
    }
    {
      command = "-workbench.action.debug.stepInto";
      key = "f11";
      when = "debugState != 'inactive'";
    }
    {
      command = "workbench.action.debug.stepOut";
      key = "shift+f8";
      when = "debugState == 'stopped'";
    }
    {
      command = "-workbench.action.debug.stepOut";
      key = "shift+f11";
      when = "debugState == 'stopped'";
    }
    {
      command = "-workbench.action.closeEditorsInGroup";
      key = "ctrl+x 0";
      when = "!terminalFocus";
    }
    {
      command = "-workbench.action.closeWindow";
      key = "ctrl+x ctrl+c";
    }
    {
      command = "workbench.action.closeEditorInAllGroups";
      key = "ctrl+x c";
    }
    {
      command = "-workbench.action.closeAllEditors";
      key = "ctrl+k ctrl+w";
    }
    {
      command = "workbench.action.nextEditorInGroup";
      key = "ctrl+x n";
    }
    {
      command = "-workbench.action.nextEditorInGroup";
      key = "ctrl+k ctrl+pagedown";
    }
    {
      command = "-workbench.action.openEditorAtIndex1";
      key = "alt+1";
    }
    {
      command = "workbench.action.switchWindow";
      key = "ctrl+x ctrl+o";
    }
    {
      command = "-history.showPrevious";
      key = "up";
      when = "historyNavigationBackwardsEnabled && historyNavigationWidgetFocus && !isComposing && !suggestWidgetVisible";
    }
    {
      command = "-inlineChat.arrowOutUp";
      key = "up";
      when = "inlineChatFocused && inlineChatHasProvider && inlineChatInnerCursorFirst && !accessibilityModeEnabled && !isEmbeddedDiffEditor";
    }
    {
      command = "-interactive.history.previous";
      key = "up";
      when = "!suggestWidgetVisible && activeEditor == 'workbench.editor.interactive' && interactiveInputCursorAtBoundary != 'bottom' && interactiveInputCursorAtBoundary != 'none'";
    }
    {
      command = "-notifications.focusPreviousToast";
      key = "up";
      when = "notificationFocus && notificationToastsVisible";
    }
    {
      command = "-selectPrevSuggestion";
      key = "up";
      when = "suggestWidgetMultipleSuggestions && suggestWidgetVisible && textInputFocus || suggestWidgetVisible && textInputFocus && !suggestWidgetHasFocusedSuggestion";
    }
    {
      command = "-scm.viewPreviousCommit";
      key = "up";
      when = "scmInputIsInFirstPosition && scmRepository && !suggestWidgetVisible";
    }
    {
      command = "-workbench.action.interactivePlayground.arrowUp";
      key = "up";
      when = "interactivePlaygroundFocus && !editorTextFocus";
    }
    {
      command = "-workbench.action.terminal.selectPrevSuggestion";
      key = "up";
      when = "terminalFocus && terminalHasBeenCreated && terminalIsOpen && terminalSuggestWidgetVisible || terminalFocus && terminalIsOpen && terminalProcessSupported && terminalSuggestWidgetVisible";
    }
    {
      command = "-workbench.banner.focusPreviousAction";
      key = "up";
      when = "bannerFocused";
    }
    {
      command = "-workbench.statusBar.focusPrevious";
      key = "up";
      when = "statusBarFocused";
    }
    {
      command = "-iconSelectBox.focusUp";
      key = "up";
      when = "iconSelectBoxFocus";
    }
    {
      command = "-editor.action.selectPreviousStickyScrollLine";
      key = "up";
      when = "stickyScrollFocused";
    }
    {
      command = "-emacs-mcx.isearchExit";
      key = "up";
      when = "editorFocus && findWidgetVisible && !config.emacs-mcx.cursorMoveOnFindWidget && !isComposing && !replaceInputFocussed";
    }
    {
      command = "-workbench.action.terminal.selectNextSuggestion";
      key = "down";
      when = "terminalFocus && terminalHasBeenCreated && terminalIsOpen && terminalSuggestWidgetVisible || terminalFocus && terminalIsOpen && terminalProcessSupported && terminalSuggestWidgetVisible";
    }
    {
      command = "workbench.action.openRecent";
      key = "ctrl+x ctrl+o";
    }
    {
      command = "-workbench.action.openRecent";
      key = "ctrl+r";
    }
    {
      command = "workbench.action.closeEditorsAndGroup";
      key = "ctrl+x ctrl+c";
    }
    {
      command = "workbench.action.navigateBack";
      key = "ctrl+x ctrl+p";
      when = "canNavigateBack";
    }
    {
      command = "-workbench.action.navigateBack";
      key = "ctrl+alt+-";
      when = "canNavigateBack";
    }
    {
      command = "editor.debug.action.toggleBreakpoint";
      key = "ctrl+8";
      when = "debuggersAvailable && disassemblyViewFocus || debuggersAvailable && editorTextFocus";
    }
    {
      command = "-editor.debug.action.toggleBreakpoint";
      key = "f9";
      when = "debuggersAvailable && disassemblyViewFocus || debuggersAvailable && editorTextFocus";
    }
    {
      command = "editor.action.triggerSuggest";
      key = "ctrl+.";
      when = "editorTextFocus";
    }
    {
      command = "-editor.action.triggerSuggest";
      key = "ctrl+'";
      when = "editorTextFocus";
    }
    {
      command = "-welcome.showNewFileEntries";
      key = "ctrl+alt+meta+n";
    }
    {
      command = "-editor.action.clipboardPasteAction";
      key = "ctrl+v";
    }
    {
      command = "-filesExplorer.paste";
      key = "ctrl+v";
      when = "filesExplorerFocus && foldersViewVisible && !explorerResourceReadonly && !inputFocus";
    }
    {
      command = "emacs-mcx.scrollDownCommand";
      key = "alt+v";
      when = "editorTextFocus && !config.emacs-mcx.useMetaPrefixMacCmd && !suggestWidgetVisible";
    }
    {
      command = "-emacs-mcx.scrollDownCommand";
      key = "alt+v";
      when = "editorTextFocus && !config.emacs-mcx.useMetaPrefixMacCmd && !suggestWidgetVisible";
    }
    {
      command = "emacs-mcx.scrollDownCommand";
      key = "alt+v";
      when = "config.emacs-mcx.useMetaPrefixMacCmd && editorTextFocus && !suggestWidgetVisible";
    }
    {
      command = "-emacs-mcx.scrollDownCommand";
      key = "alt+v";
      when = "config.emacs-mcx.useMetaPrefixMacCmd && editorTextFocus && !suggestWidgetVisible";
    }
    {
      command = "editor.action.startFindReplaceAction";
      key = "ctrl+o";
    }
    {
      command = "editor.action.nextMatchFindAction";
      key = "enter";
      when = "editorFocus && findWidgetVisible && !replaceInputFocussed";
    }
    {
      command = "";
      key = "ctrl+a";
      when = "editorFocus && findWidgetVisible && findInputFocussed";
    }
    {
      command = "";
      key = "ctrl+b";
      when = "editorFocus && findWidgetVisible && findInputFocussed";
    }
    {
      command = "";
      key = "ctrl+e";
      when = "editorFocus && findWidgetVisible && findInputFocussed";
    }
    {
      command = "";
      key = "ctrl+f";
      when = "editorFocus && findWidgetVisible && findInputFocussed";
    }
    {
      command = "";
      key = "ctrl+n";
      when = "editorFocus && findWidgetVisible && findInputFocussed";
    }
    {
      command = "";
      key = "ctrl+p";
      when = "editorFocus && findWidgetVisible && findInputFocussed";
    }
    {
      command = "-editor.action.selectAll";
      key = "ctrl+a";
    }
    {
      command = "";
      key = "ctrl+k";
      when = "editorFocus && findWidgetVisible && findInputFocussed";
    }
    {
      command = "";
      key = "ctrl+w";
      when = "editorFocus && findWidgetVisible && findInputFocussed";
    }
    {
      command = "";
      key = "ctrl+space";
      when = "editorFocus && findWidgetVisible && findInputFocussed";
    }
    {
      command = "";
      key = "ctrl+y";
      when = "editorFocus && findWidgetVisible && findInputFocussed";
    }
    {
      command = "emacs-mcx.setMarkCommand";
      key = "ctrl+space";
      when = "editorTextFocus || findInputFocussed";
    }
    {
      command = "-emacs-mcx.setMarkCommand";
      key = "ctrl+space";
      when = "editorTextFocus";
    }
    {
      command = "emacs-mcx.cancel";
      key = "ctrl+g";
      when = "editorHasSelection && editorTextFocus && !config.emacs-mcx.useMetaPrefixEscape";
    }
    {
      command = "closeFindWidget";
      key = "ctrl+g";
      when = "editorFocus && findWidgetVisible && !isComposing";
    }
    {
      command = "-emacs-mcx.isearchExit";
      key = "ctrl+y";
      when = "editorFocus && findWidgetVisible && !isComposing";
    }
    {
      command = "emacs-mcx.yank";
      key = "ctrl+y";
      when = "(editorTextFocus && !editorReadonly) || findInputFocussed";
    }
    {
      command = "-emacs-mcx.yank";
      key = "ctrl+y";
      when = "editorTextFocus && !editorReadonly";
    }
    {
      command = "aipopup.action.modal.generate";
      key = "ctrl+shift+k";
      when = "editorFocus && !composerBarIsVisible && !composerControlPanelIsVisible";
    }
    {
      command = "-aipopup.action.modal.generate";
      key = "ctrl+k";
      when = "editorFocus && !composerBarIsVisible && !composerControlPanelIsVisible";
    }
    {
      command = "aichat.newchataction";
      key = "ctrl+shift+l";
    }
    {
      command = "-aichat.newchataction";
      key = "ctrl+l";
    }
    {
      command = "workbench.action.chat.newChat";
      key = "ctrl+shift+l";
    }
    {
      command = "-workbench.view.explorer";
      key = "ctrl+shift+e";
      when = "viewContainer.workbench.view.explorer.enabled";
    }
    {
      command = "emacs-mcx.backwardWord";
      key = "meta+b";
      when = "editorTextFocus";
    }
    {
      command = "-emacs-mcx.backwardWord";
      key = "alt+b";
      when = "config.emacs-mcx.useMetaPrefixMacCmd && editorTextFocus";
    }
    {
      command = "emacs-mcx.forwardWord";
      key = "alt+f";
      when = "editorTextFocus";
    }
    {
      command = "-emacs-mcx.forwardWord";
      key = "alt+f";
      when = "editorTextFocus && !config.emacs-mcx.useMetaPrefixMacCmd";
    }
    {
      command = "";
      key = "ctrl+x";
      when = "terminalFocus";
    }
    {
      command = "-workbench.action.toggleSidebarVisibility";
      key = "ctrl+alt+space";
      when = "!config.emacs-mcx.useMetaPrefixMacCmd";
    }
    {
      command = "-workbench.action.toggleSidebarVisibility";
      key = "ctrl+alt+space";
      when = "config.emacs-mcx.useMetaPrefixMacCmd";
    }
    {
      command = "editor.action.deleteLines";
      key = "ctrl+k";
      when = "textInputFocus && !editorReadonly";
    }
    {
      command = "-editor.action.deleteLines";
      key = "ctrl+shift+k";
      when = "textInputFocus && !editorReadonly";
    }
    {
      command = "emacs-mcx.paredit.pareditKill";
      key = "ctrl+k";
      when = "editorTextFocus";
    }
    {
      command = "-emacs-mcx.paredit.pareditKill";
      key = "ctrl+shift+k";
      when = "editorTextFocus";
    }
    {
      command = "-emacs-mcx.cancel";
      key = "escape";
      when = "editorHasSelection && editorTextFocus && !config.emacs-mcx.useMetaPrefixEscape";
    }
    {
      command = "emacs-mcx.cancel";
      key = "ctrl+g";
      when = "editorHasMultipleSelections && editorTextFocus && !config.emacs-mcx.useMetaPrefixEscape";
    }
    {
      command = "-emacs-mcx.cancel";
      key = "escape";
      when = "editorHasMultipleSelections && editorTextFocus && !config.emacs-mcx.useMetaPrefixEscape";
    }
    {
      command = "-emacs-mcx.deleteBackwardChar";
      key = "ctrl+h";
      when = "editorTextFocus && !editorReadonly";
    }
    {
      command = "deleteLeft";
      key = "ctrl+h";
      when = "textInputFocus";
    }
    {
      command = "deleteLeft";
      key = "ctrl+backspace";
      when = "textInputFocus";
    }
    {
      args = { commands = [ "workbench.view.explorer" "workbench.files.action.focusFilesExplorer" ]; };
      command = "runCommands";
      key = "ctrl+q";
    }
    {
      command = "-workbench.action.quit";
      key = "ctrl+q";
    }
    {
      command = "roo-cline.SidebarProvider.focus";
      key = "ctrl+shift+r";
    }
    {
      command = "editor.action.clipboardPasteAction";
      key = "ctrl+y";
    }
    {
      command = "-editor.action.clipboardPasteAction";
      key = "shift+insert";
    }
    {
      command = "workbench.action.terminal.pasteSelection";
      key = "ctrl+y";
      when = "terminalFocus && terminalHasBeenCreated || terminalFocus && terminalProcessSupported";
    }
    {
      command = "-workbench.action.terminal.pasteSelection";
      key = "shift+insert";
      when = "terminalFocus && terminalHasBeenCreated || terminalFocus && terminalProcessSupported";
    }
    {
      command = "composerMode.agent";
      key = "ctrl+i";
    }
    {
      command = "-workbench.action.quickOpenNavigateNextInViewPicker";
      key = "";
    }
    {
      command = "-workbench.action.quickOpenView";
      key = "";
    }
    {
      command = "-renameFile";
      key = "enter";
      when = "filesExplorerFocus && foldersViewVisible && !explorerResourceIsRoot && !explorerResourceReadonly && !inputFocus";
    }
    {
      command = "workbench.action.chat.newChat";
      key = "ctrl+shift+n";
    }
    {
      command = "-workbench.action.chat.newChat";
      key = "ctrl+l";
      when = "chatIsEnabled && inChat && chatLocation != 'editing-session'";
    }
    {
      command = "-workbench.action.newWindow";
      key = "ctrl+shift+n";
    }
    {
      command = "composer.newAgentChat";
      key = "ctrl+shift+n";
    }
    {
      command = "-composer.newAgentChat";
      key = "ctrl+shift+i";
    }
    {
      command = "-closeReferenceSearch";
      key = "escape";
      when = "inReferenceSearchEditor && !config.editor.stablePeek";
    }
    {
      command = "closeReferenceSearch";
      key = "shift+escape";
      when = "inReferenceSearchEditor";
    }
    {
      command = "-closeReferenceSearch";
      key = "shift+escape";
      when = "inReferenceSearchEditor && !config.editor.stablePeek";
    }
    {
      command = "closeReferenceSearch";
      key = "shift+escape";
      when = "editorTextFocus && referenceSearchVisible && !config.editor.stablePeek || referenceSearchVisible && !inputFocus";
    }
    {
      command = "-closeReferenceSearch";
      key = "shift+escape";
      when = "editorTextFocus && referenceSearchVisible && !config.editor.stablePeek || referenceSearchVisible && !config.editor.stablePeek && !inputFocus";
    }
    {
      command = "closeReferenceSearch";
      key = "escape";
      when = "editorTextFocus && referenceSearchVisible && !config.editor.stablePeek || referenceSearchVisible && !inputFocus";
    }
    {
      command = "-closeReferenceSearch";
      key = "escape";
      when = "editorTextFocus && referenceSearchVisible && !config.editor.stablePeek || referenceSearchVisible && !config.editor.stablePeek && !inputFocus";
    }
    {
      command = "closeReferenceSearch";
      key = "ctrl+g";
      when = "inReferenceSearchEditor";
    }
    {
      command = "-closeReferenceSearch";
      key = "ctrl+g";
      when = "inReferenceSearchEditor && !config.editor.stablePeek";
    }
    {
      command = "closeReferenceSearch";
      key = "ctrl+g";
      when = "referenceSearchVisible";
    }
    {
      command = "-closeReferenceSearch";
      key = "ctrl+g";
      when = "referenceSearchVisible && !config.editor.stablePeek";
    }
    {
      command = "workbench.action.findInFiles";
      key = "ctrl+shift+f";
    }
    {
      command = "list.focusPageDown";
      key = "ctrl+v";
      when = "explorerViewletFocus && !inputFocus";
    }
    {
      command = "list.focusPageUp";
      key = "alt+v";
      when = "explorerViewletFocus && !inputFocus";
    }
    {
      command = "editor.action.quickFix";
      key = "ctrl+.";
      when = "editorHasCodeActionsProvider && textInputFocus && !editorReadonly";
    }
    {
      command = "-editor.action.quickFix";
      key = "cmd+.";
      when = "editorHasCodeActionsProvider && textInputFocus && !editorReadonly";
    }
    {
      command = "workbench.action.chat.openInSidebar";
      key = "ctrl+]";
    }
    {
      command = "test.command";
      key = "ctrl+alt+t";
    }
    {
      key = "ctrl+]";
      command = "composer.startComposerPrompt";
      when = "cursor.appLayout != 'agent'";
    }
    {
      key = "ctrl+i";
      command = "-composer.startComposerPrompt";
      when = "cursor.appLayout != 'agent'";
    }
  ]