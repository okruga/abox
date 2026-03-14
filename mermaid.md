:::mermaid
graph TD
    subgraph Infrastructure Setup
        A[OpenTofu Bootstrap] --> B[Kubernetes Cluster]
        B --> C[Gateway API Installation]
        C --> D[Kind Load Balancer]
    end

    subgraph Application Deployment
        E[GitHub Repository] --> F[Flux CD]
        F --> G[Helm Release]
        G --> H[Production Deployment]
        
        E --> I[Preview Environment]
        I --> J[PR-based Preview]
    end

    subgraph Gateway API
        K[Gateway Class] --> L[HTTP Listener]
        L --> M[Route Management]
        M --> N[Preview Routes]
        M --> O[Production Routes]
    end

    subgraph Access Flow
        P[User Request] --> Q[Load Balancer]
        Q --> R{Request Type}
        R -->|Production| S[Production Endpoint]
        R -->|Preview| T[Preview Endpoint /pr-number]
    end

    style Infrastructure Setup fill:#f9f,stroke:#333,stroke-width:2px
    style Application Deployment fill:#bbf,stroke:#333,stroke-width:2px
    style Gateway API fill:#bfb,stroke:#333,stroke-width:2px
    style Access Flow fill:#fbb,stroke:#333,stroke-width:2px
:::