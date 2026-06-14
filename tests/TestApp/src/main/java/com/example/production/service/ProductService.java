package com.example.production.service;

import com.example.production.model.Product;
import com.example.production.repository.ProductRepository;
import org.springframework.stereotype.Service;
import java.util.List;
import java.util.Optional;

@Service
public class ProductService {
    private final ProductRepository productRepository;

    public ProductService(ProductRepository productRepository) {
        this.productRepository = productRepository;
    }

    public List<Product> getAllProducts() {
        return productRepository.findAll();
    }

    public Optional<Product> getProductById(Long id) {
        return productRepository.findById(id);
    }

    public Product createProduct(Product product) {
        return productRepository.save(product);
    }

    public boolean deleteProduct(Long id) {
        return productRepository.delete(id);
    }

    public Optional<Product> updateStock(Long id, boolean inStock) {
        return productRepository.findById(id).map(p -> {
            p.setInStock(inStock);
            return p;
        });
    }

    public int countProducts() {
        return productRepository.count();
    }
}
