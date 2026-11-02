#include "leaf-keymap.h"
#include <cassert>
#include <cstdio>

int main(int argc, char **argv) {
    assert(argc == 2);
    assert(SDL_Init(SDL_INIT_GAMECONTROLLER) == 0);
    LeafKeymap map;
    assert(map.load(argv[1]));
    int axes[SDL_CONTROLLER_AXIS_MAX] = {};
    bool buttons[SDL_CONTROLLER_BUTTON_MAX] = {};
    uint8_t keys[SDL_NUM_SCANCODES] = {};
    const SDL_GameControllerButton sources[] = {
        SDL_CONTROLLER_BUTTON_A, SDL_CONTROLLER_BUTTON_B,
        SDL_CONTROLLER_BUTTON_X, SDL_CONTROLLER_BUTTON_Y,
        SDL_CONTROLLER_BUTTON_LEFTSHOULDER, SDL_CONTROLLER_BUTTON_RIGHTSHOULDER,
        SDL_CONTROLLER_BUTTON_START, SDL_CONTROLLER_BUTTON_BACK,
        SDL_CONTROLLER_BUTTON_DPAD_UP, SDL_CONTROLLER_BUTTON_DPAD_DOWN,
        SDL_CONTROLLER_BUTTON_DPAD_LEFT, SDL_CONTROLLER_BUTTON_DPAD_RIGHT
    };
    const SDL_Scancode targets[] = {
        SDL_SCANCODE_Z, SDL_SCANCODE_X, SDL_SCANCODE_C, SDL_SCANCODE_W,
        SDL_SCANCODE_A, SDL_SCANCODE_S, SDL_SCANCODE_C, SDL_SCANCODE_RETURN,
        SDL_SCANCODE_UP, SDL_SCANCODE_DOWN, SDL_SCANCODE_LEFT, SDL_SCANCODE_RIGHT
    };
    for (unsigned i = 0; i < sizeof(sources)/sizeof(sources[0]); ++i) {
        buttons[sources[i]] = true;
        map.apply(axes, buttons, keys);
        for (int k = 0; k < SDL_NUM_SCANCODES; ++k) assert(keys[k] == (k == targets[i]));
        buttons[sources[i]] = false;
        map.apply(axes, buttons, keys);
        assert(keys[targets[i]] == 0);
    }
    axes[SDL_CONTROLLER_AXIS_TRIGGERLEFT] = 32767;
    axes[SDL_CONTROLLER_AXIS_TRIGGERRIGHT] = 32767;
    axes[SDL_CONTROLLER_AXIS_LEFTX] = -32768;
    axes[SDL_CONTROLLER_AXIS_LEFTY] = 32767;
    buttons[SDL_CONTROLLER_BUTTON_A] = true;
    map.apply(axes, buttons, keys);
    assert(keys[SDL_SCANCODE_Q] && keys[SDL_SCANCODE_D]);
    assert(keys[SDL_SCANCODE_LEFT] && keys[SDL_SCANCODE_DOWN] && keys[SDL_SCANCODE_Z]);
    // A held key must survive releasing another source for the same key.
    buttons[SDL_CONTROLLER_BUTTON_X] = true;
    buttons[SDL_CONTROLLER_BUTTON_START] = true;
    map.apply(axes, buttons, keys);
    buttons[SDL_CONTROLLER_BUTTON_X] = false;
    map.apply(axes, buttons, keys);
    assert(keys[SDL_SCANCODE_C]);
    std::memset(axes, 0, sizeof(axes));
    std::memset(buttons, 0, sizeof(buttons));
    axes[SDL_CONTROLLER_AXIS_LEFTX] = 8000;
    map.apply(axes, buttons, keys);
    for (uint8_t key : keys) assert(key == 0);
    assert(!map.load("/nonexistent/profile.keys"));
    map.apply(axes, buttons, keys);
    for (uint8_t key : keys) assert(key == 0);
    puts("controller mapping: buttons, triggers, diagonals, simultaneous keys, release and dead zone passed");
    for (int i = 0; i < SDL_NumJoysticks(); ++i) {
        char guid[33];
        SDL_JoystickGetGUIDString(SDL_JoystickGetDeviceGUID(i), guid, sizeof(guid));
        printf("device %d: %s guid=%s controller=%d\n", i, SDL_JoystickNameForIndex(i), guid, SDL_IsGameController(i));
        if (SDL_IsGameController(i)) {
            char *mapping = SDL_GameControllerMappingForGUID(SDL_JoystickGetDeviceGUID(i));
            printf("mapping: %s\n", mapping ? mapping : "none");
            SDL_free(mapping);
        }
    }
    SDL_Quit();
}
