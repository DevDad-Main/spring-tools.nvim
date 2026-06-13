package com.example.production.config;

import com.example.production.service.UserService;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

@Configuration
public class AppConfig {

    @Bean
    public String appName() {
        return "ProductionApp";
    }

    @Bean
    public Integer maxConnections() {
        return 100;
    }

    @Bean
    public String defaultGreeting(UserService userService) {
        int count = userService.countUsers();
        return "Welcome to ProductionApp (" + count + " users)";
    }
}
