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
bool                 movingPip = false;

bool isBrowserPip(const PHLWINDOW& window) {
    if (!window || !window->m_class.empty())
        return false;

    return window->m_title == "Picture in picture" || window->m_title == "ピクチャー イン ピクチャー";
}

void stopMovingPip() {
    CKeybindManager::changeMouseBindMode(MBIND_INVALID);
    movingPip = false;
}

void onMouseButton(void*, SCallbackInfo& info, std::any data) {
    const auto event = std::any_cast<IPointer::SButtonEvent>(data);

    if (event.button != BTN_RIGHT)
        return;

    if (event.state == WL_POINTER_BUTTON_STATE_RELEASED) {
        if (!movingPip)
            return;

        stopMovingPip();
        info.cancelled = true;
        return;
    }

    if (event.state != WL_POINTER_BUTTON_STATE_PRESSED || movingPip || g_pInputManager->m_dragMode != MBIND_INVALID)
        return;

    const auto mouseCoords = g_pInputManager->getMouseCoordsInternal();
    const auto window      = g_pCompositor->vectorToWindowUnified(mouseCoords, RESERVED_EXTENTS | INPUT_EXTENTS | ALLOW_FLOATING);

    if (!isBrowserPip(window))
        return;

    const auto result = CKeybindManager::changeMouseBindMode(MBIND_MOVE);
    if (!result.success || result.passEvent || g_pInputManager->m_dragMode != MBIND_MOVE || g_pInputManager->m_currentlyDraggedWindow.lock() != window)
        return;

    movingPip      = true;
    info.cancelled = true;
}
} // namespace

APICALL EXPORT std::string PLUGIN_API_VERSION() {
    return HYPRLAND_API_VERSION;
}

APICALL EXPORT PLUGIN_DESCRIPTION_INFO PLUGIN_INIT(HANDLE handle) {
    if (std::string{__hyprland_api_get_hash()} != __hyprland_api_get_client_hash())
        throw std::runtime_error("[hyprland-pip-drag] Hyprland version mismatch");

    mouseButtonHook = HyprlandAPI::registerCallbackDynamic(handle, "mouseButton", onMouseButton);
    if (!mouseButtonHook)
        throw std::runtime_error("[hyprland-pip-drag] Failed to register mouseButton hook");

    return {
        "hyprland-pip-drag",
        "Move browser picture-in-picture windows with an unmodified right drag",
        "purplehaze",
        "1.0.0",
    };
}

APICALL EXPORT void PLUGIN_EXIT() {
    if (movingPip)
        stopMovingPip();

    mouseButtonHook.reset();
}
