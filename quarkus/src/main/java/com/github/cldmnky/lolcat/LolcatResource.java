package com.github.cldmnky.lolcat;

import jakarta.ws.rs.Consumes;
import jakarta.ws.rs.POST;
import jakarta.ws.rs.Path;
import jakarta.ws.rs.Produces;
import jakarta.ws.rs.core.MediaType;

@Path("/api/lolcat")
public class LolcatResource {

    @POST
    @Consumes(MediaType.APPLICATION_JSON)
    @Produces(MediaType.APPLICATION_JSON)
    public LolcatResponse colorize(LolcatRequest request) {
        if (request.text == null || request.text.isEmpty()) {
            throw new IllegalArgumentException("text must not be empty");
        }

        String colorized = LolcatColorizer.colorize(
            request.text,
            request.seed != null ? request.seed : 0.0,
            request.spread != null ? request.spread : 3.0,
            request.freq != null ? request.freq : 0.1
        );

        return new LolcatResponse(request.text, colorized);
    }
}
