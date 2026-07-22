import { useState, useEffect } from 'react';
import { cn } from '../utils/cn';

export default function UserAvatar({ src, name, size = 'md', className = '', onClick }) {
  const [imageError, setImageError] = useState(false);

  // Reset image error state if the src changes
  useEffect(() => {
    setImageError(false);
  }, [src]);

  const initials = (name || 'U')
    .split(' ')
    .map((n) => n[0])
    .join('')
    .substring(0, 2)
    .toUpperCase();

  const sizeClasses = {
    xs: 'w-6 h-6 text-xs rounded-lg',
    sm: 'w-8 h-8 text-sm rounded-xl',
    md: 'w-10 h-10 text-base rounded-xl',
    lg: 'w-16 h-16 text-xl rounded-2xl',
    xl: 'w-24 h-24 text-3xl rounded-3xl',
  };

  const isWithImage = src && !imageError;

  return (
    <div
      onClick={onClick}
      className={cn(
        'relative flex items-center justify-center font-bold text-white shadow-sm overflow-hidden select-none transition-all duration-200',
        sizeClasses[size] || sizeClasses.md,
        !isWithImage && 'bg-gradient-to-tr from-brand-500 to-brand-400 shadow-brand-500/10',
        onClick && 'cursor-pointer hover:opacity-90 active:scale-95',
        className
      )}
    >
      {isWithImage ? (
        <img
          src={src}
          alt={name || 'Avatar'}
          onError={() => setImageError(true)}
          className="w-full h-full object-cover"
        />
      ) : (
        <span>{initials}</span>
      )}
    </div>
  );
}
