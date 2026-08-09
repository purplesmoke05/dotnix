#include <hyprland/src/Compositor.hpp>
#include <hyprland/src/desktop/Window.hpp>
#include <hyprland/src/managers/KeybindManager.hpp>
#include <hyprland/src/managers/input/InputManager.hpp>
#include <hyprland/src/plugins/PluginAPI.hpp>

#include <any>
#include <linux/input-event-codes.h>
#include <stdexcept>
#include <string>

namespace {
SP<HOOK_CALLBACK_FN> mouseButtonHook;
uint32_t             altModifierMask = 0;
bool                 draggingPip     = false;

bool isBrowserPip(const PHLWINDOW& window) {
    if (!window || !window->m_class.empty())
        return false;

    return window->m_title == "Picture in picture" || window->m_title == "ピクチャー イン ピクチャー";
}

void stopPipDrag() {
    CKeybindManager::changeMouseBindMode(MBIND_INVALID);
    draggingPip = false;
}

void onMouseButton(void*, SCallbackInfo& info, std::any data) {
    const auto event = std::any_cast<IPointer::SButtonEvent>(data);

    if (event.button != BTN_RIGHT)
        return;

    if (event.state == WL_POINTER_BUTTON_STATE_RELEASED) {
        if (!draggingPip)
            return;

        stopPipDrag();
        info.cancelled = true;
        return;
    }

    if (event.state != WL_POINTER_BUTTON_STATE_PRESSED || draggingPip || g_pInputManager->m_dragMode != MBIND_INVALID)
        return;

    const auto modifiers = g_pInputManager->getModsFromAllKBs();
    const auto dragMode  = modifiers == 0 ? MBIND_MOVE : modifiers == altModifierMask ? MBIND_RESIZE_FORCE_RATIO : MBIND_INVALID;
    if (dragMode == MBIND_INVALID)
        return;

    const auto mouseCoords = g_pInputManager->getMouseCoordsInternal();
    const auto window      = g_pCompositor->vectorToWindowUnified(mouseCoords, RESERVED_EXTENTS | INPUT_EXTENTS | ALLOW_FLOATING);

    if (!isBrowserPip(window))
        return;

    const auto result = CKeybindManager::changeMouseBindMode(dragMode);
    if (!result.success || result.passEvent || g_pInputManager->m_dragMode != dragMode || g_pInputManager->m_currentlyDraggedWindow.lock() != window)
        return;

    draggingPip    = true;
    info.cancelled = true;
}
} // namespace

APICALL EXPORT std::string PLUGIN_API_VERSION() {
    return HYPRLAND_API_VERSION;
}

APICALL EXPORT PLUGIN_DESCRIPTION_INFO PLUGIN_INIT(HANDLE handle) {
    if (std::string{__hyprland_api_get_hash()} != __hyprland_api_get_client_hash())
        throw std::runtime_error("[hyprland-pip-drag] Hyprland version mismatch");

    altModifierMask = g_pKeybindManager->stringToModMask("ALT");
    if (altModifierMask == 0)
        throw std::runtime_error("[hyprland-pip-drag] Failed to resolve the Alt modifier mask");

    mouseButtonHook = HyprlandAPI::registerCallbackDynamic(handle, "mouseButton", onMouseButton);
    if (!mouseButtonHook)
        throw std::runtime_error("[hyprland-pip-drag] Failed to register mouseButton hook");

    return {
        "hyprland-pip-drag",
        "Move browser PiP with right drag and resize it at its current aspect ratio with Alt+right drag",
        "purplehaze",
        "1.1.0",
    };
}

APICALL EXPORT void PLUGIN_EXIT() {
    if (draggingPip)
        stopPipDrag();

    mouseButtonHook.reset();
}
