/** @type {import('next').NextConfig} */
const nextConfig = {
  webpack: (config) => {
    // Опциональные зависимости WalletConnect, которые webpack иначе пытается резолвить.
    config.externals.push("pino-pretty", "lokijs", "encoding");
    return config;
  },
};

export default nextConfig;
