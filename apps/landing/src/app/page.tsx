'use client';

import Header from '@/components/Header';
import Hero from '@/components/Hero';
import Experience from '@/components/Experience';
import Features from '@/components/Features';
import Platforms from '@/components/Platforms';
import CTA from '@/components/CTA';
import Footer from '@/components/Footer';

export default function Home() {
  return (
    <>
      <Header />
      <main>
        <Hero />
        <Experience />
        <Features />
        <Platforms />
        <CTA />
      </main>
      <Footer />
    </>
  );
}
