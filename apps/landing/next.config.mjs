/** @type {import('next').NextConfig} */
const nextConfig = {
  // Static HTML export — served by Nginx as plain files, no Node runtime needed.
  output: 'export',
  images: { unoptimized: true },
  trailingSlash: true,
};

export default nextConfig;
