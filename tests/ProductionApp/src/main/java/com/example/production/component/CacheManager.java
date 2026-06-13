package com.example.production.component;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;

@Component
public class CacheManager {
    private static final Logger log = LoggerFactory.getLogger(CacheManager.class);

    private int cacheHitCount = 0;
    private long lastEviction = System.currentTimeMillis();

    public void recordHit() {
        cacheHitCount++;
    }

    public int getCacheHitCount() {
        return cacheHitCount;
    }

    public long getLastEviction() {
        return lastEviction;
    }

    @Scheduled(fixedRate = 60000)
    public void evictCache() {
        lastEviction = System.currentTimeMillis();
        log.debug("Cache evicted at {}", lastEviction);
    }
}
