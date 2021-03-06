//
//  P3DLoopsPreviewView.m
//  Pleasant3D
//
//  Created by Eberhard Rensch on 04.08.09.
//  Copyright 2009 Pleasant Software. All rights reserved.
//
//  This program is free software; you can redistribute it and/or modify it under
//  the terms of the GNU General Public License as published by the Free Software 
//  Foundation; either version 3 of the License, or (at your option) any later 
//  version.
// 
//  This program is distributed in the hope that it will be useful, but WITHOUT ANY 
//  WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A 
//  PARTICULAR PURPOSE. See the GNU General Public License for more details.
// 
//  You should have received a copy of the GNU General Public License along with 
//  this program; if not, see <http://www.gnu.org/licenses>.
// 
//  Additional permission under GNU GPL version 3 section 7
// 
//  If you modify this Program, or any covered work, by linking or combining it 
//  with the P3DCore.framework (or a modified version of that framework), 
//  containing parts covered by the terms of Pleasant Software's software license, 
//  the licensors of this Program grant you additional permission to convey the 
//  resulting work.
//

#import "P3DLoopsPreviewView.h"
#import <OpenGL/glu.h>
#import <P3DCore/P3DCore.h>

static NSArray* _extrusionColors=nil;

@implementation P3DLoopsPreviewView
{
    GLuint _arrowDL;
}
@dynamic layerInfoString, dimensionsString, userRequestedAutorotate, autorotate, maxLayers;

+ (void)initialize
{
	// 'brown', 'red', 'orange', 'yellow', 'green', 'blue', 'purple'
	_extrusionColors = [NSArray arrayWithObjects:CFBridgingRelease(CGColorCreateGenericRGB(0.855, 0.429, 0.002, 1.000)), CFBridgingRelease(CGColorCreateGenericRGB(1.000, 0.000, 0.000, 1.000)), CFBridgingRelease(CGColorCreateGenericRGB(1.000, 0.689, 0.064, 1.000)), CFBridgingRelease(CGColorCreateGenericRGB(1.000, 1.000, 0.000, 1.000)), CFBridgingRelease(CGColorCreateGenericRGB(0.367, 0.742, 0.008, 1.000)), CFBridgingRelease(CGColorCreateGenericRGB(0.607, 0.598, 1.000, 1.000)), CFBridgingRelease(CGColorCreateGenericRGB(0.821, 0.000, 0.833, 1.000)), nil];

	NSMutableDictionary *ddef = [NSMutableDictionary dictionary];
	[ddef setObject:[NSNumber numberWithBool:YES] forKey:@"P3DLoopsPreviewShowNoExtrusionPaths"];
	[[NSUserDefaults standardUserDefaults] registerDefaults:ddef];
}


+ (NSSet *)keyPathsForValuesAffectingDimensionsString {
    return [NSSet setWithObjects:@"loops", nil];
}

+ (NSSet *)keyPathsForValuesAffectingMaxLayers {
    return [NSSet setWithObjects:@"loops", nil];
}

+ (NSSet *)keyPathsForValuesAffectingLayerInfoString {
    return [NSSet setWithObjects:@"loops", @"currentLayer", nil];
}

- (void)awakeFromNib
{
	[super awakeFromNib];
		
	NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
	self.showNoExtrusionPaths = [defaults boolForKey:@"P3DLoopsPreviewShowNoExtrusionPaths"];
}


- (NSString*)dimensionsString
{
	Vector3* dimension = [_loops.cornerMaximum sub:_loops.cornerMinimum];
	
	NSNumberFormatter *numberFormatter = [[NSNumberFormatter alloc] init];
	[numberFormatter setFormatterBehavior:NSNumberFormatterBehavior10_4];
	[numberFormatter setFormat:@"0.0mm;0.0mm;-0.0mm"];
	
	NSString* dimString = [NSString stringWithFormat:@"%@ (X) x %@ (Y) x %@ (Z)", [numberFormatter stringFromNumber:[NSNumber numberWithFloat:dimension.x]], [numberFormatter stringFromNumber:[NSNumber numberWithFloat:dimension.y]], [numberFormatter stringFromNumber:[NSNumber numberWithFloat:dimension.z]]];
	return dimString;
}

- (NSString*)layerInfoString
{
	NSString* infoString = NSLocalizedString(@"Layer - of -: - mm",nil);
	if(_loops)
	{
		NSNumberFormatter *numberFormatter = [[NSNumberFormatter alloc] init];
		[numberFormatter setFormatterBehavior:NSNumberFormatterBehavior10_4];
		[numberFormatter setFormat:@"0.0mm;0.0mm;-0.0mm"];

		infoString = [NSString stringWithFormat: NSLocalizedString(@"Layer %d of %d: %@",nil), self.currentLayer+1, _loops.layers.count,[numberFormatter stringFromNumber:[NSNumber numberWithFloat:(float)self.currentLayer* _loops.extrusionHeight]]];
	}
	return infoString;
}

- (float)layerHeight
{
	if(_loops.extrusionHeight>0.)
		return _loops.extrusionHeight;
	return 1.;
}

- (NSInteger)maxLayers
{
	return _loops.layers.count-1;
}

- (void)setLoops:(P3DLoops*)value
{
	self.autorotate=[[NSUserDefaults standardUserDefaults] boolForKey:@"P3DLoopsPreviewAutorotate"];
	_loops = value;
	[self setNeedsDisplay:YES];
	//[self resetGraphics];
}

- (void)setShowNoExtrusionPaths:(BOOL)value
{
	_showNoExtrusionPaths = value;
	[[NSUserDefaults standardUserDefaults] setBool:value forKey:@"P3DLoopsPreviewShowNoExtrusionPaths"];
	[self setNeedsDisplay:YES];
}

- (void)prepareOpenGL
{
    [super prepareOpenGL];
    
    const GLfloat kArrowLen = .4f;
	
	_arrowDL = glGenLists(1);
	glNewList(_arrowDL, GL_COMPILE);
	
	glBegin(GL_TRIANGLES);
	glVertex3f(kArrowLen, kArrowLen, 0.f);
	glVertex3f(-kArrowLen, 0.f, 0.f);
	glVertex3f(kArrowLen, -kArrowLen, 0.f);
	glEnd();
	
	glEndList();
}

- (void)renderContent {
	if(_loops)
	{
		glDisable(GL_COLOR_MATERIAL);
		glDisable(GL_LIGHTING);
		glDisable(GL_LIGHT0);
		if(self.threeD)
		{
			NSUInteger layerNumber=0;
			for(NSArray* layer in _loops.layers)
			{
				glLineWidth((layerNumber==self.currentLayer)?1.f:2.f);

				GLfloat z = (GLfloat)layerNumber*(GLfloat)_loops.extrusionHeight;
				
				NSInteger loopNummer = 0;
				InsetLoopCorner* lastCorner = nil;
				for(P3DMutableLoopIndexArray* loop in layer)
				{
					BOOL inLoop=NO;
					if(self.currentLayer > layerNumber)
						glColor4f(.5f, .5f, .5f, .2f*powf((GLfloat)self.othersAlpha,3.f)); 
					else if(self.currentLayer < layerNumber)
						glColor4f(.5f, .5f, .5f, (.5f*powf((GLfloat)self.othersAlpha,3.f))/(1.f+20.f*powf((GLfloat)self.othersAlpha, 3.f))); 
					else
						glColor4f(.5f, .5f, .5f, .2f);

					if(!_showNoExtrusionPaths)
						lastCorner = nil;
					NSInteger count = loop.count;
					for(NSUInteger pointIndex=0;pointIndex<count;pointIndex++)
					{
						InsetLoopCorner* corner = &(_loops.loopCorners[[loop integerAtIndex:pointIndex]]);
						if(lastCorner)
						{
							glBegin(GL_LINES);
							glVertex3f((GLfloat)lastCorner->point.s[0], (GLfloat)lastCorner->point.s[1], z);
							glVertex3f((GLfloat)corner->point.s[0], (GLfloat)corner->point.s[1], z);
							glEnd();

							if(layerNumber==self.currentLayer)
							{
//								glBegin(GL_LINES);
//								glVertex3f(corner->point[0],corner->point[1],z);
//								glVertex3f(corner->normal[0],corner->normal[1],z);
//								glEnd();
									
								if(self.showArrows)
								{
									glPushMatrix();
									glTranslatef((GLfloat)((corner->point.s[0]+lastCorner->point.s[0])/2.f), (GLfloat)((corner->point.s[1]+lastCorner->point.s[1])/2.f), z);
									glRotatef((GLfloat)(180.f*atan2f((corner->point.s[1]-lastCorner->point.s[1]), ((corner->point.s[0]-lastCorner->point.s[0])))/M_PI), 0.f, 0.f, 1.f);
									glCallList(_arrowDL);
									glPopMatrix();
								}
							}
						}
						if(!inLoop)
						{
							inLoop=YES;
							const CGFloat* loopColor = CGColorGetComponents((__bridge CGColorRef)[_extrusionColors objectAtIndex:loopNummer++%[_extrusionColors count]]);
							if(self.currentLayer > layerNumber)
								glColor4f((GLfloat)loopColor[0], (GLfloat)loopColor[1], (GLfloat)loopColor[2], (GLfloat)loopColor[3]*powf((GLfloat)self.othersAlpha,3.f)); 
							else if(self.currentLayer < layerNumber)
								glColor4f((GLfloat)loopColor[0], (GLfloat)loopColor[1], (GLfloat)loopColor[2], ((GLfloat)loopColor[3]*powf((GLfloat)self.othersAlpha,3.f))/(1.f+20.f*powf((GLfloat)self.othersAlpha, 3.f))); 
							else
								glColor4f((GLfloat)loopColor[0], (GLfloat)loopColor[1], (GLfloat)loopColor[2], (GLfloat)loopColor[3]);
						}
						lastCorner = corner;
					}
				}
				layerNumber++;
			}
		}
		else
		{		
			if(self.currentLayer<_loops.layers.count)
			{			
				glLineWidth(2.f);
				NSInteger loopNummer = 0;
				InsetLoopCorner* lastCorner = nil;
				for(PSMutableIntegerArray* loop in [_loops.layers objectAtIndex:self.currentLayer])
				{
					BOOL inLoop=NO;
					glColor4f(.5f, .5f, .5f, .2f);
						
					if(!_showNoExtrusionPaths)
						lastCorner = nil;
					NSInteger count = loop.count;
					for(NSUInteger pointIndex=0;pointIndex<count;pointIndex++)
					{
						InsetLoopCorner* corner = &(_loops.loopCorners[[loop integerAtIndex:pointIndex]]);
						if(lastCorner)
						{
							glBegin(GL_LINES);
							glVertex3f((GLfloat)lastCorner->point.s[0], (GLfloat)lastCorner->point.s[1], 0.f);
							glVertex3f((GLfloat)corner->point.s[0], (GLfloat)corner->point.s[1], 0.f);
							glEnd();
							
							if(self.showArrows)
							{
								glPushMatrix();
								glTranslatef((GLfloat)((corner->point.s[0]+lastCorner->point.s[0])/2.f), (GLfloat)((corner->point.s[1]+lastCorner->point.s[1])/2.f), 0.f);
								glRotatef((GLfloat)(180.f*atan2f((corner->point.s[1]-lastCorner->point.s[1]), ((corner->point.s[0]-lastCorner->point.s[0])))/M_PI), 0.f, 0.f, 1.f);
								glCallList(_arrowDL);
								glPopMatrix();
							}
						}
						if(!inLoop)
						{
							inLoop=YES;
							const CGFloat* loopColor = CGColorGetComponents((__bridge CGColorRef)[_extrusionColors objectAtIndex:loopNummer++%[_extrusionColors count]]);
							glColor4f((GLfloat)loopColor[0], (GLfloat)loopColor[1], (GLfloat)loopColor[2], (GLfloat)loopColor[3]);
						}
						
						lastCorner = corner;
					}
				}
			}
		}
	}
}

@end
