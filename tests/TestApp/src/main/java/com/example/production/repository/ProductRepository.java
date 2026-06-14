package com.example.production.repository;

import com.example.production.model.Product;
import org.springframework.stereotype.Repository;
import java.util.*;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.atomic.AtomicLong;

@Repository
public class ProductRepository {
    private final Map<Long, Product> store = new ConcurrentHashMap<>();
    private final AtomicLong idGen = new AtomicLong(1);

    public List<Product> findAll() {
        return new ArrayList<>(store.values());
    }

    public Optional<Product> findById(Long id) {
        return Optional.ofNullable(store.get(id));
    }

    public Product save(Product product) {
        if (product.getId() == null) {
            product.setId(idGen.getAndIncrement());
        }
        store.put(product.getId(), product);
        return product;
    }

    public boolean delete(Long id) {
        return store.remove(id) != null;
    }

    public int count() {
        return store.size();
    }
}
