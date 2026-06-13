package com.example.production.service;

import com.example.production.model.Product;
import com.example.production.repository.ProductRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.util.List;
import java.util.Optional;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class ProductServiceTest {

    @Mock
    private ProductRepository productRepository;

    private ProductService productService;

    @BeforeEach
    void setUp() {
        productService = new ProductService(productRepository);
    }

    @Test
    void getAllProducts() {
        when(productRepository.findAll()).thenReturn(List.of(
                new Product(1L, "Widget", 9.99, true),
                new Product(2L, "Gadget", 24.99, false)
        ));
        var products = productService.getAllProducts();
        assertThat(products).hasSize(2);
    }

    @Test
    void getProductByIdFound() {
        var product = new Product(1L, "Widget", 9.99, true);
        when(productRepository.findById(1L)).thenReturn(Optional.of(product));
        var result = productService.getProductById(1L);
        assertThat(result).isPresent();
        assertThat(result.get().getName()).isEqualTo("Widget");
    }

    @Test
    void createProduct() {
        var input = new Product(null, "NewProduct", 14.99, true);
        var saved = new Product(1L, "NewProduct", 14.99, true);
        when(productRepository.save(any())).thenReturn(saved);
        var result = productService.createProduct(input);
        assertThat(result.getId()).isEqualTo(1L);
    }

    @Test
    void updateStock() {
        var product = new Product(1L, "Widget", 9.99, true);
        when(productRepository.findById(1L)).thenReturn(Optional.of(product));
        var result = productService.updateStock(1L, false);
        assertThat(result).isPresent();
        assertThat(result.get().isInStock()).isFalse();
    }
}
