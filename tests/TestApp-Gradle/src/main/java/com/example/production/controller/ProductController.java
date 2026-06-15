package com.example.production.controller;

import com.example.production.model.Product;
import com.example.production.service.ProductService;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;
import java.util.List;
import java.util.Map;

@RestController
@RequestMapping("/api/products")
public class ProductController {
    private final ProductService productService;

    public ProductController(ProductService productService) {
        this.productService = productService;
    }

    @GetMapping
    public List<Product> getAllProducts() {
        return productService.getAllProducts();
    }

    @GetMapping("/{id}")
    public ResponseEntity<Product> getProductById(@PathVariable Long id) {
        return productService.getProductById(id)
                .map(ResponseEntity::ok)
                .orElse(ResponseEntity.notFound().build());
    }

    @GetMapping("/{productId}/reviews/{reviewId}")
    public ResponseEntity<Map<String, String>> getReview(
            @PathVariable Long productId,
            @PathVariable Long reviewId) {
        return ResponseEntity.ok(Map.of(
            "productId", String.valueOf(productId),
            "reviewId", String.valueOf(reviewId),
            "rating", "5",
            "text", "Great product!"
        ));
    }

    @GetMapping("/category/{category}/{subcategory}")
    public ResponseEntity<Map<String, String>> byCategory(
            @PathVariable String category,
            @PathVariable String subcategory) {
        return ResponseEntity.ok(Map.of(
            "category", category,
            "subcategory", subcategory,
            "count", "42"
        ));
    }

    @PostMapping
    public ResponseEntity<Product> createProduct(@RequestBody Product product) {
        Product created = productService.createProduct(product);
        return ResponseEntity.status(HttpStatus.CREATED).body(created);
    }

    @DeleteMapping("/{id}")
    public ResponseEntity<Void> deleteProduct(@PathVariable Long id) {
        if (productService.deleteProduct(id)) {
            return ResponseEntity.noContent().build();
        }
        return ResponseEntity.notFound().build();
    }

    @PatchMapping("/{id}/stock")
    public ResponseEntity<Product> updateStock(@PathVariable Long id, @RequestBody Map<String, Boolean> body) {
        boolean inStock = body.getOrDefault("inStock", false);
        return productService.updateStock(id, inStock)
                .map(ResponseEntity::ok)
                .orElse(ResponseEntity.notFound().build());
    }
}

