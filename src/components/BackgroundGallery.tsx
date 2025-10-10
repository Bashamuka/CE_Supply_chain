import React, { useState, useEffect } from 'react';

interface BackgroundImage {
  url: string;
  position: string;
}

interface BackgroundGalleryProps {
  images: BackgroundImage[];
  interval?: number; // in milliseconds
}

export function BackgroundGallery({ images, interval = 5000 }: BackgroundGalleryProps) {
  const [currentIndex, setCurrentIndex] = useState(0);

  useEffect(() => {
    if (images.length <= 1) return;

    const timer = setInterval(() => {
      setCurrentIndex((prevIndex) => (prevIndex + 1) % images.length);
    }, interval);

    return () => clearInterval(timer);
  }, [images.length, interval]);

  if (images.length === 0) return null;

  return (
    <div className="relative h-full w-full">
      {images.map((image, index) => (
        <div
          key={index}
          className={`absolute inset-0 bg-center bg-no-repeat transition-opacity duration-1000 ${
            index === currentIndex ? 'opacity-100' : 'opacity-0'
          }`}
          style={{
            backgroundImage: `url('${image.url}')`,
            backgroundPosition: image.position,
            backgroundSize: 'cover',
          }}
        />
      ))}
    </div>
  );
}