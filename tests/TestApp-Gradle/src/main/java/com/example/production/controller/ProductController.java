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

    @GetMapping("/catalog")
    public ResponseEntity<Map<String, Object>> catalog() {
        return ResponseEntity.ok(Map.of(
            "store", "TestApp Store",
            "version", "1.0.0",
            "departments", java.util.List.of(
                Map.of("name", "Electronics", "floor", 2, "open", true,
                    "items", java.util.List.of(
                        Map.of("id", 1, "name", "Laptop", "price", 999.99, "stock", 15, "specs", Map.of("ram", "16GB", "cpu", "i7", "storage", "512GB SSD")),
                        Map.of("id", 2, "name", "Phone", "price", 699.99, "stock", 42, "specs", Map.of("ram", "8GB", "cpu", "A15", "storage", "256GB")),
                        Map.of("id", 3, "name", "Tablet", "price", 449.99, "stock", 8, "specs", Map.of("ram", "6GB", "cpu", "M2", "storage", "128GB"))
                    )),
                Map.of("name", "Books", "floor", 1, "open", false,
                    "items", java.util.List.of(
                        Map.of("id", 101, "title", "Spring Boot in Action", "author", "Craig Walls", "price", 39.99, "pages", 450),
                        Map.of("id", 102, "title", "Clean Code", "author", "Robert Martin", "price", 29.99, "pages", 464),
                        Map.of("id", 103, "title", "Designing Data-Intensive Applications", "author", "Martin Kleppmann", "price", 44.99, "pages", 616)
                    )),
                Map.of("name", "Clothing", "floor", 3, "open", true,
                    "items", java.util.List.of(
                        Map.of("id", 201, "name", "T-Shirt", "price", 19.99, "sizes", java.util.List.of("S", "M", "L", "XL")),
                        Map.of("id", 202, "name", "Jeans", "price", 49.99, "sizes", java.util.List.of("30", "32", "34")),
                        Map.of("id", 203, "name", "Jacket", "price", 89.99, "sizes", java.util.List.of("M", "L"))
                    ))
            ),
            "metadata", Map.of(
                "total_items", 9,
                "total_departments", 3,
                "last_updated", "2026-06-15T10:00:00Z",
                "server", Map.of(
                    "host", "store-01",
                    "region", "eu-west-1",
                    "uptime_seconds", 86400
                )
            )
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

