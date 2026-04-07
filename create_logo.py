#!/usr/bin/env python3
"""
Script pour créer le logo Chafin avec le "C" bleu
"""

from PIL import Image, ImageDraw, ImageFont
import os

def create_chafin_logo():
    # Taille du logo (1024x1024 pour iOS)
    size = 1024
    
    # Créer une image avec fond transparent
    img = Image.new('RGBA', (size, size), (255, 255, 255, 0))
    draw = ImageDraw.Draw(img)
    
    # Couleur bleu pour le "C"
    blue_color = (0, 123, 255, 255)  # Bleu moderne
    
    # Centrer le "C"
    center_x = size // 2
    center_y = size // 2
    
    # Taille du "C" (80% de la taille totale)
    letter_size = int(size * 0.8)
    
    # Calculer la position du "C"
    left = center_x - letter_size // 2
    top = center_y - letter_size // 2
    right = center_x + letter_size // 2
    bottom = center_y + letter_size // 2
    
    # Épaisseur du trait
    stroke_width = size // 10
    
    # Dessiner le "C" comme un arc
    # Arc extérieur
    draw.arc(
        [(left, top), (right, bottom)],
        start=45,  # Angle de début
        end=315,   # Angle de fin (pour laisser l'ouverture à droite)
        fill=blue_color,
        width=stroke_width
    )
    
    # Pour un "C" plus épais, ajoutons plusieurs arcs
    for i in range(stroke_width):
        draw.arc(
            [(left + i, top + i), (right - i, bottom - i)],
            start=45,
            end=315,
            fill=blue_color,
            width=2
        )
    
    # Sauvegarder le logo
    logo_path = "/Users/yoannbeugre/Documents/Documents - MacBook Pro de Yoann/DEV/Chafin/assets/images/logo.png"
    img.save(logo_path, "PNG")
    print(f"Logo créé : {logo_path}")
    
    # Créer aussi une version avec fond blanc pour l'icône d'app
    img_white = Image.new('RGBA', (size, size), (255, 255, 255, 255))
    draw_white = ImageDraw.Draw(img_white)
    
    # Redessiner le "C" sur fond blanc
    for i in range(stroke_width):
        draw_white.arc(
            [(left + i, top + i), (right - i, bottom - i)],
            start=45,
            end=315,
            fill=blue_color,
            width=2
        )
    
    # Ajouter un léger ombrage
    shadow_offset = 5
    shadow_color = (0, 0, 0, 50)
    for i in range(stroke_width):
        draw_white.arc(
            [(left + i + shadow_offset, top + i + shadow_offset), (right - i + shadow_offset, bottom - i + shadow_offset)],
            start=45,
            end=315,
            fill=shadow_color,
            width=1
        )
    
    # Redessiner le "C" par-dessus l'ombre
    for i in range(stroke_width):
        draw_white.arc(
            [(left + i, top + i), (right - i, bottom - i)],
            start=45,
            end=315,
            fill=blue_color,
            width=2
        )
    
    icon_path = "/Users/yoannbeugre/Documents/Documents - MacBook Pro de Yoann/DEV/Chafin/assets/images/icon.png"
    img_white.save(icon_path, "PNG")
    print(f"Icône créée : {icon_path}")

if __name__ == "__main__":
    create_chafin_logo()
