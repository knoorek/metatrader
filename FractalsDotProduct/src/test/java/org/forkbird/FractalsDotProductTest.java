package org.forkbird;

import org.junit.jupiter.api.Test;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.CsvSource;
import org.junit.jupiter.params.provider.ValueSource;

import java.io.File;
import java.io.IOException;
import java.math.BigDecimal;
import java.net.URISyntaxException;
import java.nio.file.Files;
import java.time.*;
import java.util.List;
import java.util.stream.Stream;

import static org.assertj.core.api.AssertionsForInterfaceTypes.assertThat;
import static org.forkbird.FractalsDotProduct.*;
import static org.forkbird.FractalsDotProduct.toHighLows;


public class FractalsDotProductTest {

    @Test
    void fractals() throws URISyntaxException, IOException {
        try (Stream<String> lines = Files.lines(file("/fractals.csv").toPath())) {
            List<Fractal> fractals = FractalsDotProduct.fractals(toHighLows(lines));

            assertThat(fractals).hasSize(2);
            assertThat(fractals.get(0).value()).isEqualTo(new BigDecimal("1.43520"));
            assertThat(fractals.get(0).dateTime()).isEqualTo(zonedDateTime("2024.01.18 00:00:00"));
            assertThat(fractals.get(1).value()).isEqualTo(new BigDecimal("1.60652"));
            assertThat(fractals.get(1).dateTime()).isEqualTo(zonedDateTime("2024.01.03 00:00:00"));
        }
    }

    @Test
    void valueDiff() {
        var clock = Clock.fixed(Instant.now(), ZoneId.systemDefault());
        var fractals = List.of(
                new Fractal(Clock.offset(clock, Duration.ofDays(3)).instant().atZone(ZoneId.systemDefault()), new BigDecimal(10), null),
                new Fractal(Clock.offset(clock, Duration.ofDays(2)).instant().atZone(ZoneId.systemDefault()), new BigDecimal(5), null),
                new Fractal(Clock.offset(clock, Duration.ofDays(1)).instant().atZone(ZoneId.systemDefault()), new BigDecimal(15), null)
        );
        List<Fractal> result = FractalsDotProduct.valueDiff(fractals);

        assertThat(result).containsExactly(
                new Fractal(Clock.offset(clock, Duration.ofDays(3)).instant().atZone(ZoneId.systemDefault()), new BigDecimal(10), new BigDecimal("1.0000")),
                new Fractal(Clock.offset(clock, Duration.ofDays(2)).instant().atZone(ZoneId.systemDefault()), new BigDecimal(5), new BigDecimal("-0.6666"))
        );
    }

    @Test
    void fractalsPatterns() throws URISyntaxException, IOException {
        try (Stream<String> lines = Files.lines(file("/fractalsPatterns.csv").toPath())) {
            List<FractalsPattern> fractalsPatterns = FractalsDotProduct.fractalsPatterns(FractalsDotProduct.fractals(toHighLows(lines)), 2);

            assertThat(fractalsPatterns).hasSize(3);
            assertThat(fractalsPatterns.get(0).fractals()).containsExactly(
                    new Fractal(zonedDateTime("2024.01.28 00:00:00"), new BigDecimal("1.43519"), null),
                    new Fractal(zonedDateTime("2024.01.23 00:00:00"), new BigDecimal("1.60654"), null)
            );
            assertThat(fractalsPatterns.get(1).fractals()).containsExactly(
                    new Fractal(zonedDateTime("2024.01.23 00:00:00"), new BigDecimal("1.60654"), null),
                    new Fractal(zonedDateTime("2024.01.18 00:00:00"), new BigDecimal("1.43520"), null)
            );
            assertThat(fractalsPatterns.get(2).fractals()).containsExactly(
                    new Fractal(zonedDateTime("2024.01.18 00:00:00"), new BigDecimal("1.43520"), null),
                    new Fractal(zonedDateTime("2024.01.03 00:00:00"), new BigDecimal("1.60652"), null)
            );
        }
    }

    @ParameterizedTest
    @ValueSource(ints = {1, 2, 3, 4, 5})
    void fractalsPattern(int patternSize) throws URISyntaxException, IOException {
        int fractalsInFile = 4;
        try (Stream<String> lines = Files.lines(file("/fractalsPatterns.csv").toPath())) {
            List<FractalsPattern> fractalsPatterns = FractalsDotProduct.fractalsPatterns(FractalsDotProduct.fractals(toHighLows(lines)), patternSize);

            assertThat(fractalsPatterns).hasSize(fractalsInFile - patternSize + 1);
        }
    }

    @ParameterizedTest
    @CsvSource({"1,1,2,2,1.0000", "1,1,-1,1,0.0000", "1,1,-1,-1,-1.0000"})
    void cosine(String a1, String a2, String b1, String b2, String cos) {
        var fractalsPattern1 = new FractalsPattern(List.of(
                new Fractal(null, null, new BigDecimal(a1)),
                new Fractal(null, null, new BigDecimal(a2))
        ));
        var fractalsPattern2 = new FractalsPattern(List.of(
                new Fractal(null, null, new BigDecimal(b1)),
                new Fractal(null, null, new BigDecimal(b2))
        ));

        BigDecimal cosine = fractalsPattern1.cosine(fractalsPattern2);

        assertThat(cosine).isEqualTo(new BigDecimal(cos));
    }

    @Test
    void calculateCosines() {
        FractalsPattern e1 = new FractalsPattern(List.of(
                new Fractal(zonedDateTime("2024.01.18 00:00:00"), null, new BigDecimal(1)),
                new Fractal(zonedDateTime("2024.01.17 00:00:00"), null, new BigDecimal(1))
        ));
        FractalsPattern e2 = new FractalsPattern(List.of(
                new Fractal(zonedDateTime("2024.01.16 00:00:00"), null, new BigDecimal(-1)),
                new Fractal(zonedDateTime("2024.01.15 00:00:00"), null, new BigDecimal(1))
        ));
        FractalsPattern e3 = new FractalsPattern(List.of(
                new Fractal(zonedDateTime("2024.01.14 00:00:00"), null, new BigDecimal(1)),
                new Fractal(zonedDateTime("2024.01.13 00:00:00"), null, new BigDecimal(1))
        ));
        List<FractalsPattern> fractalsPatterns = List.of(e1, e2, e3);

        List<CosineResult> result = FractalsDotProduct.calculateCosines(fractalsPatterns, BigDecimal.ZERO, BigDecimal.ZERO);

        assertThat(result.stream().map(CosineResult::cosine)).containsExactly(new BigDecimal("1.0000"), new BigDecimal("0.0000"));
        assertThat(result.get(0).base()).isEqualTo(e1);
        assertThat(result.get(0).target()).isEqualTo(e3);
        assertThat(result.get(1).base()).isEqualTo(e1);
        assertThat(result.get(1).target()).isEqualTo(e2);
    }

    @Test
    void processFile() throws URISyntaxException, IOException {
        List<CosineResult> result = FractalsDotProduct.processFile(file("/fractalsPatterns.csv"), 2, new BigDecimal("-1"), BigDecimal.ZERO, false);
        assertThat(result).hasSize(1);
    }

    private File file(String filename) throws URISyntaxException {
        return new File(this.getClass().getResource(filename).toURI());
    }

    private static ZonedDateTime zonedDateTime(String text) {
        return ZonedDateTime.parse(text, dateTimeFormatter);
    }
}

