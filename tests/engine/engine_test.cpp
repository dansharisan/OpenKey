//
//  engine_test.cpp
//  OpenKey engine tests
//
//  Feeds key sequences into the typing engine and replays its output the same
//  way the macOS app does (OpenKey.mm), so typing bugs can be checked without
//  the GUI. Unicode code table only.
//
//  Run: tests/engine/run.sh
//

#include <cstdio>
#include <cstdlib>
#include <unistd.h>
#include <string>
#include <vector>
#include <functional>
#include "../../Sources/OpenKey/engine/Engine.h"

// Settings the engine reads; the app defines these in AppDelegate.m.
int vLanguage = 1;
int vInputType = vTelex;
int vFreeMark = 0;
int vCodeTable = 0;
int vSwitchKeyStatus = 0;
int vCheckSpelling = 1;
int vUseModernOrthography = 1;
int vQuickTelex = 0;
int vRestoreIfWrongSpelling = 0;
int vFixRecommendBrowser = 1;
int vUseMacro = 0;
int vUseMacroInEnglishMode = 0;
int vAutoCapsMacro = 0;
int vUseSmartSwitchKey = 0;
int vUpperCaseFirstChar = 0;
int vTempOffSpelling = 0;
int vAllowConsonantZFWJ = 0;
int vQuickStartConsonant = 0;
int vQuickEndConsonant = 0;
int vRememberCode = 0;
int vOtherLanguage = 0;
int vTempOffOpenKey = 0;

static vKeyHookState* pData;

// Key used in test strings for the delete (backspace) key.
static const char BACKSPACE = '<';
// Character used in test strings for a mouse click (the app starts a new word and ignores the output).
static const char MOUSE_CLICK = '@';
// Character used in test strings for tapping Cmd to turn the engine off for the next word.
static const char TEMP_OFF = '^';

struct KeyStroke {
    Uint16 code;
    bool caps;
};

static bool toKeyStroke(char c, KeyStroke& out) {
    static const char* letters = "abcdefghijklmnopqrstuvwxyz";
    static const Uint16 letterCodes[] = {
        KEY_A, KEY_B, KEY_C, KEY_D, KEY_E, KEY_F, KEY_G, KEY_H, KEY_I, KEY_J, KEY_K, KEY_L, KEY_M,
        KEY_N, KEY_O, KEY_P, KEY_Q, KEY_R, KEY_S, KEY_T, KEY_U, KEY_V, KEY_W, KEY_X, KEY_Y, KEY_Z
    };
    static const char* digits = "1234567890";
    static const Uint16 digitCodes[] = { KEY_1, KEY_2, KEY_3, KEY_4, KEY_5, KEY_6, KEY_7, KEY_8, KEY_9, KEY_0 };

    for (int i = 0; letters[i]; i++) {
        if (c == letters[i]) { out = { letterCodes[i], false }; return true; }
        if (c == letters[i] - 32) { out = { letterCodes[i], true }; return true; }
    }
    for (int i = 0; digits[i]; i++) {
        if (c == digits[i]) { out = { digitCodes[i], false }; return true; }
    }
    switch (c) {
        case ' ': out = { KEY_SPACE, false }; return true;
        case '.': out = { KEY_DOT, false }; return true;
        case ',': out = { KEY_COMMA, false }; return true;
        case ';': out = { KEY_SEMICOLON, false }; return true;
        case '\'': out = { KEY_QUOTE, false }; return true;
        case '/': out = { KEY_SLASH, false }; return true;
        case '-': out = { KEY_MINUS, false }; return true;
        case '[': out = { KEY_LEFT_BRACKET, false }; return true;
        case ']': out = { KEY_RIGHT_BRACKET, false }; return true;
        case '\n': out = { KEY_RETURN, false }; return true;
        case BACKSPACE: out = { KEY_DELETE, false }; return true;
    }
    return false;
}

static void appendUtf8(std::string& s, Uint32 cp) {
    if (cp < 0x80) {
        s += (char)cp;
    } else if (cp < 0x800) {
        s += (char)(0xC0 | (cp >> 6));
        s += (char)(0x80 | (cp & 0x3F));
    } else {
        s += (char)(0xE0 | (cp >> 12));
        s += (char)(0x80 | ((cp >> 6) & 0x3F));
        s += (char)(0x80 | (cp & 0x3F));
    }
}

// The character the app gets when a key event is passed through or re-sent.
static Uint16 keyChar(const KeyStroke& k) {
    if (k.code == KEY_RETURN) return '\n';
    return keyCodeToCharacter(k.code | (k.caps ? CAPS_MASK : 0));
}

// Mirrors SendNewCharString() in OpenKey.mm for the Unicode code table.
static Uint16 engineDataToChar(Uint32 data) {
    if (data & PURE_CHARACTER_MASK) return (Uint16)data;
    if (!(data & CHAR_CODE_MASK)) return keyCodeToCharacter(data);
    return (Uint16)data;
}

// Types `keys` into a fresh session and returns the resulting text.
static std::string type(const std::string& keys) {
    std::vector<Uint16> text;
    // Start like after a click, which also clears what earlier tests left behind (such as the macro key).
    vKeyHandleEvent(vKeyEvent::Mouse, vKeyEventState::MouseDown, 0);
    for (char c : keys) {
        if (c == MOUSE_CLICK) {
            vKeyHandleEvent(vKeyEvent::Mouse, vKeyEventState::MouseDown, 0);
            continue;
        }
        if (c == TEMP_OFF) {
            vToggleTempOffEngine();
            continue;
        }
        KeyStroke k;
        if (!toKeyStroke(c, k)) {
            fprintf(stderr, "unsupported key '%c' in test input\n", c);
            return "<bad input>";
        }
        vKeyHandleEvent(vKeyEvent::Keyboard, vKeyEventState::KeyDown, k.code, k.caps ? 1 : 0, false);
        if (pData->code != vDoNothing && (pData->newCharCount > MAX_BUFF || pData->backspaceCount > MAX_BUFF)) {
            fprintf(stderr, "engine output too long (backspace=%d, new=%d) for keys \"%s\" inputType=%d\n",
                    pData->backspaceCount, pData->newCharCount, keys.c_str(), vInputType);
            abort();
        }

        if (pData->code == vDoNothing) {
            // The original key event goes through to the app.
            if (k.code == KEY_DELETE) {
                if (!text.empty()) text.pop_back();
            } else {
                Uint16 ch = keyChar(k);
                if (ch) text.push_back(ch);
            }
        } else if (pData->code == vWillProcess || pData->code == vRestore || pData->code == vRestoreAndStartNewSession) {
            // The original key event is swallowed and replaced by the engine output.
            for (int i = 0; i < pData->backspaceCount && !text.empty(); i++) text.pop_back();
            for (int i = pData->newCharCount - 1; i >= 0; i--) text.push_back(engineDataToChar(pData->charData[i]));
            if (pData->code == vRestore || pData->code == vRestoreAndStartNewSession) {
                Uint16 ch = keyChar(k);
                if (ch) text.push_back(ch);
            }
            if (pData->code == vRestoreAndStartNewSession) startNewSession();
        } else if (pData->code == vReplaceMaro) {
            for (int i = 0; i < pData->backspaceCount && !text.empty(); i++) text.pop_back();
            for (Uint32 d : pData->macroData) text.push_back(engineDataToChar(d));
            Uint16 ch = keyChar(k);
            if (ch) text.push_back(ch);
        }
    }
    std::string out;
    for (Uint16 ch : text) appendUtf8(out, ch);
    return out;
}

// Restores the default settings before each test.
static void resetSettings() {
    vLanguage = 1;
    vInputType = vTelex;
    vFreeMark = 0;
    vCodeTable = 0;
    vCheckSpelling = 1;
    vUseModernOrthography = 1;
    vQuickTelex = 0;
    vRestoreIfWrongSpelling = 0;
    vUseMacro = 0;
    vAutoCapsMacro = 0;
    vUpperCaseFirstChar = 0;
    vAllowConsonantZFWJ = 0;
    vQuickStartConsonant = 0;
    vQuickEndConsonant = 0;
    vSetCheckSpelling();
    vTempOffEngine(false);
    initMacroMap(nullptr, 0);
}

struct TestCase {
    const char* name;
    const char* keys;
    const char* expected;
    std::function<void()> setup;
};

int main(int argc, char** argv) {
    pData = (vKeyHookState*)vKeyInit();

    bool probe = argc > 1 && std::string(argv[1]) == "--probe";
    if (probe) {
        // Print what the engine produces for each argument, for exploring behaviour.
        for (int i = 2; i < argc; i++) {
            resetSettings();
            printf("%-24s -> %s\n", argv[i], type(argv[i]).c_str());
        }
        return 0;
    }

    bool fuzz = argc > 1 && std::string(argv[1]) == "--fuzz";
    if (fuzz) {
        // Type random key sequences under every input method and setting combination.
        // Run under the sanitizers to catch out-of-bounds access; output is not checked.
        int rounds = argc > 2 ? atoi(argv[2]) : 20000;
        const std::string alphabet = "aaeeiioouuywwddssffrrjjxxzzbcghklmnpqtv1234567890 .,;'/-[]<<<AEWD^@";
        srand(argc > 3 ? atoi(argv[3]) : 12345);
        for (int r = 0; r < rounds; r++) {
            resetSettings();
            vInputType = r % 4;
            vCheckSpelling = (r / 4) % 2; vSetCheckSpelling();
            vRestoreIfWrongSpelling = (r / 8) % 2;
            vQuickTelex = (r / 16) % 2;
            vQuickStartConsonant = (r / 32) % 2;
            vQuickEndConsonant = (r / 64) % 2;
            vUseModernOrthography = (r / 128) % 2;
            vAllowConsonantZFWJ = (r / 256) % 2;
            vFreeMark = (r / 512) % 2;
            vUseMacro = (r / 1024) % 2;
            if (vUseMacro) {
                addMacro("ko", "không");
                addMacro("thương", "thương mại");
                addMacro(":)", "☺");
            }
            std::string keys;
            int len = 1 + rand() % 120;
            for (int i = 0; i < len; i++) keys += alphabet[rand() % alphabet.size()];
            if (getenv("FUZZ_TRACE")) {
                // The last line printed before a sanitizer report is the failing case.
                fprintf(stderr, "round=%d inputType=%d spell=%d restore=%d quickTelex=%d quickStart=%d quickEnd=%d modern=%d zfwj=%d freeMark=%d keys=\"%s\"\n",
                        r, vInputType, vCheckSpelling, vRestoreIfWrongSpelling, vQuickTelex, vQuickStartConsonant,
                        vQuickEndConsonant, vUseModernOrthography, vAllowConsonantZFWJ, vFreeMark, keys.c_str());
            }
            type(keys);
        }
        printf("fuzz: %d rounds done\n", rounds);
        return 0;
    }

    auto telex = []() {};
    auto vni = []() { vInputType = vVNI; };
    auto simpleTelex1 = []() { vInputType = vSimpleTelex1; };
    auto oldOrthography = []() { vUseModernOrthography = 0; };
    auto restoreWrongSpelling = []() { vRestoreIfWrongSpelling = 1; };
    auto quickTelex = []() { vQuickTelex = 1; };
    auto noSpellCheck = []() { vCheckSpelling = 0; vSetCheckSpelling(); };

    std::vector<TestCase> tests = {
        // Basic Telex
        { "telex: tieng viet", "tieesng vieejt", "tiếng việt", telex },
        { "telex: duong", "dduwowngf", "đường", telex },
        { "telex: nguyen", "nguyeenx", "nguyễn", telex },
        { "telex: quoc", "quoocs", "quốc", telex },
        { "telex: khong", "khoong", "không", telex },
        { "telex: thuo", "thuowr", "thuở", telex },
        { "telex: gia", "giaf", "già", telex },
        { "telex: huych", "huyjch", "huỵch", telex },
        { "telex: e hoi", "er", "ẻ", telex },
        { "telex: w alone", "w", "ư", telex },
        { "telex: mark after final consonant", "vietej", "việt", telex },

        // Undo by repeating the key
        { "telex: ss undoes sac", "ass", "as", telex },
        { "telex: aaa", "aaa", "aa", telex },
        { "telex: ddd", "ddd", "dd", telex },

        // Capitals
        { "telex: Capitalised", "Vieejt", "Việt", telex },
        { "telex: all caps", "VIEEJT", "VIỆT", telex },

        // Orthography
        { "orthography: modern hoa", "hoaf", "hoà", telex },
        { "orthography: old hoa", "hoaf", "hòa", oldOrthography },
        { "orthography: modern thuy", "thuys", "thuý", telex },
        { "orthography: old thuy", "thuys", "thúy", oldOrthography },

        // Backspace
        { "backspace: drop final consonant", "tieesng<", "tiến", telex },

        // VNI
        { "vni: viet", "vie65t", "việt", vni },
        { "vni: duong", "d9u7o7ng2", "đường", vni },

        // Simple Telex: w alone is not ư
        { "simple telex 1: w alone", "w", "w", simpleTelex1 },

        // Quick Telex
        { "quick telex: cc -> ch", "cc", "ch", quickTelex },

        // Spell checking off still types Vietnamese
        { "no spell check: viet", "vieejt", "việt", noSpellCheck },

        // Restore keys for invalid words
        { "restore: windows", "windows ", "windows ", restoreWrongSpelling },
        { "restore: valid word kept", "vieejt ", "việt ", restoreWrongSpelling },

        // Temporarily turn off the engine for one word (Cmd tap in the app)
        { "temp off: windows", "^windows", "windows", telex },
        { "temp off: next word is Vietnamese again", "^windows vieejt", "windows việt", telex },
        { "temp off: in the middle of a sentence", "tieesng ^windows", "tiếng windows", telex },
        { "temp off: a second Cmd tap cancels it", "^^vieejt", "việt", telex },
        { "temp off: cancelled in the middle of a word", "^vie^ejt", "việt", telex },
        { "temp off: backspace while off", "^ab<c", "ac", telex },
        { "temp off: backspace while off keeps the earlier letters", "vie^x<^ej", "việ", telex },

        // A mouse click starts a new word, even after an invalid word
        { "mouse click: new word after invalid word", "network@tieengs", "networktiếng", restoreWrongSpelling },
        { "mouse click: new word after misspelled toned word", "tiengs@tieengs", "tiéngtiếng", restoreWrongSpelling },

        // Macros
        { "macro: expands", "ko,", "không,", []() { vUseMacro = 1; addMacro("ko", "không"); } },
        { "macro: expands twice after break keys", "ko\nko\n", "không\nkhông\n", []() { vUseMacro = 1; addMacro("ko", "không"); } },
        { "macro: key typed with a horn on the earlier vowel", "thuowng ", "thương mại ", []() { vUseMacro = 1; addMacro("thương", "thương mại"); } },
        { "macro: key typed with quick telex", "ccao ", "chào bạn ", []() { vUseMacro = 1; vQuickTelex = 1; addMacro("chao", "chào bạn"); } },

        // Restore after deleting a character made from several keys
        { "restore: after backspace over composed char", "tas<owq ", "towq ", restoreWrongSpelling },

        // Quick start consonant
        { "quick start consonant: f -> ph", "fanh ", "phanh ", []() { vQuickStartConsonant = 1; } },
        // w is ư in Telex, so w -> qu only applies where w is not a tone key
        { "quick start consonant: w -> qu in VNI", "wen ", "quen ", []() { vQuickStartConsonant = 1; vInputType = vVNI; } },
        { "quick start consonant: Telex w is still ư", "wowts ", "ướt ", []() { vQuickStartConsonant = 1; } },
        { "quick start consonant: Telex wa is ưa", "wa ", "ưa ", []() { vQuickStartConsonant = 1; } },

        // Capital TH / Q followed by uo
        { "caps: THUOWR", "THUOWR", "THUỞ", telex },
        { "caps: QUOW", "QUOW", "QUƠ", telex },

        // Restore English words typed with a doubled mark key (the second key undoes the mark)
        { "restore: sorry", "sorry ", "sorry ", restoreWrongSpelling },
        { "restore: class", "class ", "class ", restoreWrongSpelling },
        { "restore: coffee", "coffee ", "coffee ", restoreWrongSpelling },
        { "restore: password", "password ", "password ", restoreWrongSpelling },
        { "restore: VNI doubled mark key", "a11 ", "a11 ", []() { vRestoreIfWrongSpelling = 1; vInputType = vVNI; } },
        { "restore: valid word after undo is kept", "baans ", "bấn ", restoreWrongSpelling },
        { "restore: đ abbreviation is kept", "ddc ", "đc ", restoreWrongSpelling },
        { "restore: DDT abbreviation is kept", "DDT ", "ĐT ", restoreWrongSpelling },
        { "restore: word brought back by backspace is kept", "ddc nhe<<<< ", "đc ", restoreWrongSpelling },
        { "restore: invalid word brought back by backspace is kept", "abc x<< ", "abc ", restoreWrongSpelling },
        { "restore: invalid word brought back across two spaces is kept", "hello x <<< ", "hello ", restoreWrongSpelling },
        { "restore: restored word brought back by backspace stays restored", "tiengs x<< ", "tiengs ", restoreWrongSpelling },
        { "restore: after backspace keeps marks of what is left", "tuows<q ", "tuwq ", restoreWrongSpelling },

        // Quick telex keeps the capital of the first letter
        { "quick telex: Ccaof", "Ccaof ", "Chào ", quickTelex },
        { "quick telex: Ttif", "Ttif ", "Thì ", quickTelex },

        // A w typed after the horn was added automatically is not an undo
        { "horn: nuwocws", "nuwocws", "nước", telex },
        { "horn: tuwongwf", "tuwongwf", "tường", telex },

        // uo followed by u is ươu
        { "horn: huwou", "huwou", "hươu", telex },
        { "horn: ruwouj", "ruwouj", "rượu", telex },

        // đ typed after the rest of the word
        { "late d: doatdj", "doatdj", "đoạt", telex },
        { "late d: diudj", "diudj", "địu", telex },
        { "late d: duomdwj", "duomdwj", "đượm", telex },
        { "late d: VNI doat95", "doat95", "đoạt", vni },

        // th + uo + w gives ươ whenever something follows uo
        { "horn: thuocws with free mark", "thuocws", "thước", []() { vFreeMark = 1; } },
        { "horn: thuowcs", "thuowcs", "thước", telex },
        { "horn: thuowr is still thuở", "thuowr", "thuở", telex },
    };

    int failed = 0;

    // The toggle reports the new state, which the apps use to play the off or on sound.
    {
        resetSettings();
        type("");
        bool first = vToggleTempOffEngine();
        bool second = vToggleTempOffEngine();
        if (!first || second) {
            failed++;
            printf("FAIL  %-44s first=%d second=%d\n", "temp off: toggle reports off then on", first, second);
        } else {
            printf("ok    temp off: toggle reports off then on\n");
        }
    }

    // A space after a delete must not be reported to the app as another delete (it pops its
    // VNI Windows / Unicode compound key lengths on extCode 2).
    {
        resetSettings();
        type("as<");
        vKeyHandleEvent(vKeyEvent::Keyboard, vKeyEventState::KeyDown, KEY_SPACE, 0, false);
        if (pData->code == vDoNothing && pData->extCode == 2) {
            failed++;
            printf("FAIL  %-44s extCode=%d\n", "space after delete: extCode", pData->extCode);
        } else {
            printf("ok    space after delete: extCode\n");
        }
    }

    // Convert tool
    {
        struct ConvertCase { const char* name; Uint8 from, to; const char* text; const char* expected; };
        std::vector<ConvertCase> converts = {
            { "convert: no case option keeps case", 0, 0, "Việt Nam Đường", "Việt Nam Đường" },
            { "convert: unicode to unicode compound", 0, 3, "bã", nullptr },
            { "convert: unicode to VNI Windows", 0, 2, "bã", nullptr },
            { "convert: unicode to CP1258", 0, 4, "bã", nullptr },
        };
        for (const ConvertCase& c : converts) {
            resetSettings();
            convertToolToAllCaps = convertToolToAllNonCaps = convertToolToCapsFirstLetter = false;
            convertToolToCapsEachWord = convertToolRemoveMark = false;
            convertToolFromCode = c.from;
            convertToolToCode = c.to;
            std::string actual;
            std::string expected;
            if (c.expected) {
                actual = convertUtil(c.text);
                expected = c.expected;
            } else {
                // the last character must convert like any other: compare with a trailing space
                actual = convertUtil(c.text) + " ";
                expected = convertUtil(std::string(c.text) + " ");
            }
            if (actual != expected) {
                failed++;
                printf("FAIL  %-44s expected=\"%s\" actual=\"%s\"\n", c.name, expected.c_str(), actual.c_str());
            } else {
                printf("ok    %s\n", c.name);
            }
        }
    }

    // Saved macro and smart switch data cut short at every length must load without reading past the end.
    {
        resetSettings();
        addMacro("ko", "không");
        addMacro("thương", "thương mại");
        std::vector<Byte> saved;
        getMacroSaveData(saved);
        for (size_t len = 0; len <= saved.size(); len++) {
            std::vector<Byte> cut(saved.begin(), saved.begin() + len);
            initMacroMap(cut.data(), (int)cut.size());
        }
        setAppInputMethodStatus("com.apple.Safari", 1);
        std::vector<Byte> switchData;
        getSmartSwitchKeySaveData(switchData);
        for (size_t len = 0; len <= switchData.size(); len++) {
            std::vector<Byte> cut(switchData.begin(), switchData.begin() + len);
            initSmartSwitchKey(cut.data(), (int)cut.size());
        }
        printf("ok    truncated saved data\n");
    }

    // Macro files saved on Windows (CRLF line endings) import without a trailing \r.
    {
        resetSettings();
        char path[] = "/tmp/openkey_engine_test_XXXXXX";
        int fd = mkstemp(path);
        FILE* f = fdopen(fd, "wb");
        fputs(";OpenKey macro\r\nko:không\r\n", f);
        fclose(f);
        readFromFile(path, false);
        remove(path);
        vUseMacro = 1;
        std::string actual = type("ko,");
        if (actual != "không,") {
            failed++;
            printf("FAIL  %-44s expected=\"không,\" actual=\"%s\"\n", "macro: import CRLF file", actual.c_str());
        } else {
            printf("ok    macro: import CRLF file\n");
        }
    }

    for (const TestCase& t : tests) {
        resetSettings();
        t.setup();
        std::string actual = type(t.keys);
        if (actual != t.expected) {
            failed++;
            printf("FAIL  %-44s keys=\"%s\" expected=\"%s\" actual=\"%s\"\n", t.name, t.keys, t.expected, actual.c_str());
        } else {
            printf("ok    %s\n", t.name);
        }
    }
    printf("\n%zu tests, %d failed\n", tests.size(), failed);
    return failed == 0 ? 0 : 1;
}
