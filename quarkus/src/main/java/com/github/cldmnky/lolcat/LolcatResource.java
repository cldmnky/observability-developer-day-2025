package com.github.cldmnky.lolcat;

import io.micrometer.core.instrument.Counter;
import io.micrometer.core.instrument.MeterRegistry;
import io.micrometer.core.instrument.Timer;
import jakarta.inject.Inject;
import jakarta.ws.rs.Consumes;
import jakarta.ws.rs.GET;
import jakarta.ws.rs.POST;
import jakarta.ws.rs.Path;
import jakarta.ws.rs.Produces;
import jakarta.ws.rs.core.MediaType;

@Path("/api/lolcat")
public class LolcatResource {

    @Inject
    MeterRegistry registry;
    
    private Counter colorizationsCounter;
    private Counter errorsCounter;
    private Timer colorizationTimer;
    
    @jakarta.annotation.PostConstruct
    void init() {
        colorizationsCounter = registry.counter("lolcat.colorizations.total");
        errorsCounter = registry.counter("lolcat.errors.total");
        colorizationTimer = registry.timer("lolcat.colorization.duration");
    }

    @POST
    @Consumes(MediaType.APPLICATION_JSON)
    @Produces(MediaType.APPLICATION_JSON)
    public LolcatResponse colorize(LolcatRequest request) {
        return colorizationTimer.record(() -> {
            try {
                if (request.text == null || request.text.isEmpty()) {
                    errorsCounter.increment();
                    throw new IllegalArgumentException("text must not be empty");
                }

                String colorized = LolcatColorizer.colorize(
                    request.text,
                    request.seed != null ? request.seed : 0.0,
                    request.spread != null ? request.spread : 3.0,
                    request.freq != null ? request.freq : 0.1
                );

                colorizationsCounter.increment();
                return new LolcatResponse(request.text, colorized);
            } catch (Exception e) {
                errorsCounter.increment();
                throw e;
            }
        });
    }
    
    @GET
    @Path("/health")
    @Produces(MediaType.APPLICATION_JSON)
    public String health() {
        return "{\"status\": \"ok\", \"service\": \"lolcat-api\"}";
    }
}
