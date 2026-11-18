#include <hyprland/src/desktop/state/ViewHitTester.hpp>
#include <hyprland/src/desktop/state/ViewState.hpp>
#include <hyprland/src/desktop/view/window/Window.hpp>
#include <hyprland/src/desktop/view/window/WindowMetadata.hpp>
#include <hyprland/src/event/EventBus.hpp>
#include <hyprland/src/input/Keys.hpp>
#include <hyprland/src/layout/LayoutManager.hpp>
#include <hyprland/src/layout/supplementary/DragController.hpp>
#include <hyprland/src/layout/target/Target.hpp>
#include <hyprland/src/managers/input/InputManager.hpp>
#include <hyprland/src/plugins/PluginAPI.hpp>

#include <linux/input-event-codes.h>
#include <stdexcept>
#include <string>

namespace {
CHyprSignalListener mouseButtonListener;
bool                draggingPip = false;

// Ignore lock keys such as NumLock and CapsLock when reading modifiers. / 修飾キーを読むときは NumLock や CapsLock などのロックキーを無視する。
constexpr Input::ModifierMask RELEVANT_MODIFIERS = Input::HL_MODIFIER_SHIFT | Input::HL_MODIFIER_CTRL | Input::HL_MODIFIER_ALT | Input::HL_MODIFIER_META;

bool isBrowserPip(const PHLWINDOW& window) {
    if (!window || !window->metadata().appID().empty())
        return false;

    const auto& title = window->metadata().title();
    return title == "Picture in picture" || title == "ピクチャー イン ピクチャー";
}

void stopPipDrag() {
    if (g_layoutManager->dragController()->target())
        g_layoutManager->endDragTarget();

    draggingPip = false;
}

void onMouseButton(IPointer::SButtonEvent event, Event::SCallbackInfo& info) {
    if (event.button != BTN_RIGHT)
        return;

    if (event.state == WL_POINTER_BUTTON_STATE_RELEASED) {
        if (!draggingPip)
            return;

        stopPipDrag();
        info.cancelled = true;
        return;
    }

    if (event.state != WL_POINTER_BUTTON_STATE_PRESSED || draggingPip || g_layoutManager->dragController()->target())
        return;

    // Right drag moves the PiP; Alt + right drag resizes it at its current aspect ratio. / 右ドラッグで PiP を移動し、Alt + 右ドラッグで今の縦横比のままリサイズする。
    const auto     modifiers = g_pInputManager->getModsFromAllKBs() & RELEVANT_MODIFIERS;
    eMouseBindMode dragMode  = MBIND_INVALID;
    if (!modifiers)
        dragMode = MBIND_MOVE;
    else if (modifiers == Input::ModifierMask{Input::HL_MODIFIER_ALT})
        dragMode = MBIND_RESIZE_FORCE_RATIO;
    else
        return;

    const auto window = Desktop::viewState()->hitTest().windowAt(g_pInputManager->getMouseCoordsInternal(),
                                                                 Desktop::View::RESERVED_EXTENTS | Desktop::View::INPUT_EXTENTS | Desktop::View::ALLOW_FLOATING);
    if (!isBrowserPip(window))
        return;

    g_layoutManager->beginDragTarget(window->layoutTarget(), dragMode);

    const auto& drag = g_layoutManager->dragController();
    if (!drag->target() || drag->target()->window() != window || drag->mode() != dragMode)
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

    // Hyprland 0.57 delivers input through the event bus; registerCallbackDynamic no longer does anything. / Hyprland 0.57 は入力をイベントバスで渡す。registerCallbackDynamic は何もしなくなった。
    mouseButtonListener = Event::bus()->m_events.input.mouse.button.listen(onMouseButton);

    return {
        "hyprland-pip-drag",
        "Move browser PiP with right drag and resize it at its current aspect ratio with Alt+right drag",
        "purplehaze",
        "2.0.0",
    };
}

APICALL EXPORT void PLUGIN_EXIT() {
    if (draggingPip)
        stopPipDrag();

    mouseButtonListener.reset();
}
