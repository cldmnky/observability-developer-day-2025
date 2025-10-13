package com.github.cldmnky.lolcat;

import org.junit.jupiter.api.Test;

import static org.junit.jupiter.api.Assertions.*;

public class LolcatColorizerTest {

    @Test
    public void testColorizeContainsAnsiCodes() {
        String result = LolcatColorizer.colorize("Hello", 0.0, 3.0, 0.1);
        assertTrue(result.contains("\u001b[38;2;"), "Should contain ANSI color codes");
        assertTrue(result.contains("\u001b[0m"), "Should contain ANSI reset codes");
    }

    @Test
    public void testColorizeEmptyString() {
        String result = LolcatColorizer.colorize("", 0.0, 3.0, 0.1);
        assertEquals("", result, "Empty string should return empty string");
    }

    @Test
    public void testColorizePreservesWhitespace() {
        String result = LolcatColorizer.colorize("A B C", 0.0, 3.0, 0.1);
        assertTrue(result.contains(" "), "Should preserve whitespace");
    }

    @Test
    public void testColorizeWithDifferentSeeds() {
        String result1 = LolcatColorizer.colorize("Test", 0.0, 3.0, 0.1);
        String result2 = LolcatColorizer.colorize("Test", 10.0, 3.0, 0.1);
        assertNotEquals(result1, result2, "Different seeds should produce different outputs");
    }

    @Test
    public void testColorizePreservesNewlines() {
        String input = "Line 1\nLine 2\nLine 3";
        String result = LolcatColorizer.colorize(input, 0.0, 3.0, 0.1);
        long inputNewlines = input.chars().filter(ch -> ch == '\n').count();
        long resultNewlines = result.chars().filter(ch -> ch == '\n').count();
        assertEquals(inputNewlines, resultNewlines, "Should preserve newlines");
    }

    @Test
    public void testColorizeNullDefaults() {
        String result = LolcatColorizer.colorize("Test", 0.0, 0.0, 0.0);
        assertNotNull(result, "Should handle default parameters");
        assertTrue(result.contains("\u001b[38;2;"), "Should still colorize with default parameters");
    }
}
