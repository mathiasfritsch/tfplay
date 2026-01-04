using Microsoft.AspNetCore.Builder;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using Npgsql;
using System.Collections.Generic;
using System.Threading.Tasks;
using Amazon;
using Amazon.RDS.Util;
using System.Net.Http;

var builder = WebApplication.CreateBuilder(args);
builder.WebHost.UseUrls("http://0.0.0.0:8080");

var app = builder.Build();

// Helper function to get IAM auth token
string GetRdsAuthToken(string hostname, int port, string username)
{
    // Use static method to generate token
    return RDSAuthTokenGenerator.GenerateAuthToken(hostname, port, username);
}

// Helper function to get connection string with IAM token
string GetConnectionString()
{
    var dbHost = Environment.GetEnvironmentVariable("DB_HOST") ?? "localhost";
    var dbName = Environment.GetEnvironmentVariable("DB_NAME") ?? "catalogdb";
    var dbUser = Environment.GetEnvironmentVariable("DB_USER") ?? "dbadmin";
    
    var authToken = GetRdsAuthToken(dbHost, 5432, dbUser);
    
    return $"Host={dbHost};Database={dbName};Username={dbUser};Password={authToken};SSL Mode=Require;Trust Server Certificate=true";
}

app.MapGet("/", () => "Hello from .NET Web API with PostgreSQL and IAM Authentication!");
app.MapGet("/health", () => new { status = "healthy", timestamp = DateTime.UtcNow });

// Get all products
app.MapGet("/products", async () =>
{
    var products = new List<object>();
    var connectionString = GetConnectionString();
    await using var conn = new NpgsqlConnection(connectionString);
    await conn.OpenAsync();
    
    await using var cmd = new NpgsqlCommand("SELECT id, name FROM products ORDER BY id", conn);
    await using var reader = await cmd.ExecuteReaderAsync();
    
    while (await reader.ReadAsync())
    {
        products.Add(new { id = reader.GetInt32(0), name = reader.GetString(1) });
    }
    
    return Results.Ok(products);
});

// Add a new product
app.MapPost("/products", async (ProductRequest product) =>
{
    var connectionString = GetConnectionString();
    await using var conn = new NpgsqlConnection(connectionString);
    await conn.OpenAsync();
    
    await using var cmd = new NpgsqlCommand(
        "INSERT INTO products (name) VALUES ($1) RETURNING id, name", conn);
    cmd.Parameters.AddWithValue(product.name);
    
    await using var reader = await cmd.ExecuteReaderAsync();
    await reader.ReadAsync();
    
    var newProduct = new { id = reader.GetInt32(0), name = reader.GetString(1) };
    return Results.Created($"/products/{newProduct.id}", newProduct);
});

app.Run();

record ProductRequest(string name);
